package main

import (
	"flag"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/dokku/dokku/plugins/common"
)

const (
	helpHeader = `Usage: dokku proxy[:COMMAND]

Manage the proxy integration for an app

Additional commands:`

	helpContent = `
    proxy:build-config [--parallel count] [--all|<app>], (Re)builds config for a given app
    proxy:clear-config [--all|<app>], Clears config for a given app
    proxy:disable <app>, Disable proxy for app
    proxy:enable <app>, Enable proxy for app
    proxy:report [<app>] [<flag>], Displays a proxy report for one or more apps
    proxy:set <app> <proxy-type>, Set proxy type for app`
)

func main() {
	flag.Usage = usage
	flag.Parse()

	cmd := flag.Arg(0)
	switch cmd {
	case "proxy", "proxy:help":
		usage()
	case "help":
		result, err := common.CallExecCommand(common.ExecCommandInput{
			Command: "ps",
			Args:    []string{"-o", "command=", strconv.Itoa(os.Getppid())},
		})
		if err == nil && strings.Contains(result.StdoutContents(), "--all") {
			fmt.Println(helpContent)
		} else {
			fmt.Print("\n    proxy, Manage the proxy integration for an app\n")
		}
	default:
		dokkuNotImplementExitCode, err := strconv.Atoi(os.Getenv("DOKKU_NOT_IMPLEMENTED_EXIT"))
		if err != nil {
			fmt.Println("failed to retrieve DOKKU_NOT_IMPLEMENTED_EXIT environment variable")
			dokkuNotImplementExitCode = 10
		}
		os.Exit(dokkuNotImplementExitCode)
	}
}

func usage() {
	common.CommandUsage(helpHeader, helpContent)
}
