package logs

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"html/template"
	"net/url"
	"os"
	"path/filepath"
	"strings"

	"github.com/dokku/dokku/plugins/common"
	"github.com/joncalhoun/qson"
)

type vectorConfig struct {
	Sources map[string]vectorSource `json:"sources"`
	Sinks   map[string]vectorSink   `json:"sinks"`
}

type vectorSource struct {
	Type          string   `json:"type"`
	IncludeLabels []string `json:"include_labels,omitempty"`
}

type vectorTemplateData struct {
	DokkuLibRoot string
	DokkuLogsDir string
	VectorImage  string
}

type vectorSink map[string]interface{}

const vectorContainerName = "vector-vector-1"
const vectorOldContainerName = "vector"

func getComposeFile() ([]byte, error) {
	result, err := common.CallPlugnTrigger(common.PlugnTriggerInput{
		Trigger: "vector-template-source",
	})
	if err == nil && result.ExitCode == 0 && strings.TrimSpace(result.Stdout) != "" {
		contents, err := os.ReadFile(strings.TrimSpace(result.Stdout))
		if err != nil {
			return []byte{}, fmt.Errorf("Unable to read compose template: %s", err)
		}

		return contents, nil
	}

	contents, err := templates.ReadFile("templates/compose.yml.tmpl")
	if err != nil {
		return []byte{}, fmt.Errorf("Unable to read compose template: %s", err)
	}

	return contents, nil
}

func startVectorContainer(vectorImage string) error {
	if !common.IsComposeInstalled() {
		return errors.New("Required docker compose plugin is not installed")
	}

	if common.ContainerExists(vectorOldContainerName) {
		return errors.New("Vector container %s already exists in old format, run 'dokku logs:vector-stop' once to remove it")
	}

	tmpFile, err := os.CreateTemp(os.TempDir(), "vector-compose-*.yml")
	if err != nil {
		return fmt.Errorf("Unable to create temporary file: %s", err)
	}
	defer os.Remove(tmpFile.Name())

	contents, err := getComposeFile()
	if err != nil {
		return fmt.Errorf("Unable to read compose template: %s", err)
	}

	tmpl, err := template.New("compose.yml").Parse(string(contents))
	if err != nil {
		return fmt.Errorf("Unable to parse compose template: %s", err)
	}

	dokkuLibRoot := os.Getenv("DOKKU_LIB_HOST_ROOT")
	if dokkuLibRoot == "" {
		dokkuLibRoot = os.Getenv("DOKKU_LIB_ROOT")
	}

	dokkuLogsDir := os.Getenv("DOKKU_LOGS_HOST_DIR")
	if dokkuLogsDir == "" {
		dokkuLogsDir = os.Getenv("DOKKU_LOGS_DIR")
	}

	data := vectorTemplateData{
		DokkuLibRoot: dokkuLibRoot,
		DokkuLogsDir: dokkuLogsDir,
		VectorImage:  vectorImage,
	}

	if err := tmpl.Execute(tmpFile, data); err != nil {
		return fmt.Errorf("Unable to execute compose template: %s", err)
	}

	result, err := common.CallExecCommand(common.ExecCommandInput{
		Command: common.DockerBin(),
		Args: []string{
			"compose",
			"--file", tmpFile.Name(),
			"--project-name", "vector",
			"up",
			"--detach",
			"--quiet-pull",
		},
		StreamStdio: true,
	})
	if err != nil || result.ExitCode != 0 {
		return fmt.Errorf("Unable to start vector container: %s", result.Stderr)
	}

	return nil
}

func getComputedVectorImage() string {
	return common.PropertyGetDefault("logs", "--global", "vector-image", getDefaultVectorImage())
}

// getDefaultVectorImage returns the default image used for the vector container
func getDefaultVectorImage() string {
	contents := strings.TrimSpace(VectorDockerfile)
	parts := strings.SplitN(contents, " ", 2)
	return parts[1]
}

func stopVectorContainer() error {
	if !common.IsComposeInstalled() {
		return errors.New("Required docker compose plugin is not installed")
	}

	if common.ContainerExists(vectorOldContainerName) {
		common.ContainerRemove(vectorOldContainerName)
	}

	tmpFile, err := os.CreateTemp(os.TempDir(), "vector-compose-*.yml")
	if err != nil {
		return fmt.Errorf("Unable to create temporary file: %s", err)
	}
	defer os.Remove(tmpFile.Name())

	contents, err := getComposeFile()
	if err != nil {
		return fmt.Errorf("Unable to read compose template: %s", err)
	}

	tmpl, err := template.New("compose.yml").Parse(string(contents))
	if err != nil {
		return fmt.Errorf("Unable to parse compose template: %s", err)
	}

	dokkuLibRoot := os.Getenv("DOKKU_LIB_HOST_ROOT")
	if dokkuLibRoot == "" {
		dokkuLibRoot = os.Getenv("DOKKU_LIB_ROOT")
	}

	dokkuLogsDir := os.Getenv("DOKKU_LOGS_HOST_DIR")
	if dokkuLogsDir == "" {
		dokkuLogsDir = os.Getenv("DOKKU_LOGS_DIR")
	}

	data := vectorTemplateData{
		DokkuLibRoot: dokkuLibRoot,
		DokkuLogsDir: dokkuLogsDir,
		VectorImage:  getComputedVectorImage(),
	}

	if err := tmpl.Execute(tmpFile, data); err != nil {
		return fmt.Errorf("Unable to execute compose template: %s", err)
	}

	result, err := common.CallExecCommand(common.ExecCommandInput{
		Command: common.DockerBin(),
		Args: []string{
			"compose",
			"--file", tmpFile.Name(),
			"--project-name", "vector",
			"down",
			"--remove-orphans",
		},
		StreamStdio: true,
	})
	if err != nil || result.ExitCode != 0 {
		return fmt.Errorf("Unable to stop vector container: %s", result.Stderr)
	}

	return nil
}

func sinkValueToConfig(appName string, sinkValue string) (vectorSink, error) {
	var data vectorSink
	if strings.Contains(sinkValue, "://") {
		parts := strings.SplitN(sinkValue, "://", 2)
		parts[0] = strings.ReplaceAll(parts[0], "_", "-")
		sinkValue = strings.Join(parts, "://")
	}
	u, err := url.Parse(sinkValue)
	if err != nil {
		return data, err
	}

	if u.Query().Get("sinks") != "" {
		return data, errors.New("Invalid option sinks")
	}

	u.Scheme = strings.ReplaceAll(u.Scheme, "-", "_")

	query := u.RawQuery
	query = strings.TrimPrefix(query, "&")

	b, err := qson.ToJSON(query)
	if err != nil {
		return data, err
	}

	if err := json.Unmarshal(b, &data); err != nil {
		return data, err
	}

	data["type"] = u.Scheme
	data["inputs"] = []string{"docker-source:" + appName}
	if appName == "--global" {
		data["inputs"] = []string{"docker-global-source"}
	}
	if appName == "--null" {
		data["inputs"] = []string{"docker-null-source"}
	}

	return data, nil
}

func writeVectorConfig() error {
	apps, _ := common.UnfilteredDokkuApps()
	data := vectorConfig{
		Sources: map[string]vectorSource{},
		Sinks:   map[string]vectorSink{},
	}
	for _, appName := range apps {
		value := common.PropertyGet("logs", appName, "vector-sink")
		if value == "" {
			continue
		}

		inflectedAppName := strings.ReplaceAll(appName, ".", "-")
		sink, err := sinkValueToConfig(inflectedAppName, value)
		if err != nil {
			return err
		}

		data.Sources[fmt.Sprintf("docker-source:%s", inflectedAppName)] = vectorSource{
			Type:          "docker_logs",
			IncludeLabels: []string{fmt.Sprintf("com.dokku.app-name=%s", appName)},
		}

		data.Sinks[fmt.Sprintf("docker-sink:%s", inflectedAppName)] = sink
	}

	value := common.PropertyGet("logs", "--global", "vector-sink")
	if value != "" {
		sink, err := sinkValueToConfig("--global", value)
		if err != nil {
			return err
		}

		data.Sources["docker-global-source"] = vectorSource{
			Type:          "docker_logs",
			IncludeLabels: []string{"com.dokku.app-name"},
		}

		data.Sinks["docker-global-sink"] = sink
	}

	if len(data.Sources) == 0 {
		// pull from no containers
		data.Sources["docker-null-source"] = vectorSource{
			Type:          "docker_logs",
			IncludeLabels: []string{"com.dokku.vector-null"},
		}
	}

	if len(data.Sinks) == 0 {
		// write logs to a blackhole
		sink, err := sinkValueToConfig("--null", VectorDefaultSink)
		if err != nil {
			return err
		}

		data.Sinks["docker-null-sink"] = sink
	}

	b, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return err
	}

	b = bytes.Replace(b, []byte("\\u0026"), []byte("&"), -1)
	b = bytes.Replace(b, []byte("\\u002B"), []byte("+"), -1)

	vectorConfig := filepath.Join(common.GetDataDirectory("logs"), "vector.json")
	if err := common.WriteBytesToFile(common.WriteBytesToFileInput{
		Bytes:    b,
		Filename: vectorConfig,
		Mode:     os.FileMode(0600),
	}); err != nil {
		return err
	}

	return nil
}
