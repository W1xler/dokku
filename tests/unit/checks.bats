#!/usr/bin/env bats

load test_helper

#!/usr/bin/env bats

load test_helper

setup() {
  global_setup
  create_app
}

teardown() {
  destroy_app
  global_teardown
}

@test "(checks) checks:help" {
  run /bin/bash -c "dokku checks"
  echo "output: $output"
  echo "status: $status"
  assert_output_contains "Manage zero-downtime settings"
  help_output="$output"

  run /bin/bash -c "dokku checks:help"
  echo "output: $output"
  echo "status: $status"
  assert_output_contains "Manage zero-downtime settings"
  assert_output "$help_output"
}

@test "(checks) checks:disable" {
  run /bin/bash -c "dokku checks:disable $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_DISABLED"
  echo "output: $output"
  echo "status: $status"
  assert_output "_all_"
}

@test "(checks) checks:disable -> checks:enable" {
  run /bin/bash -c "dokku checks:disable $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_DISABLED"
  echo "output: $output"
  echo "status: $status"
  assert_output "_all_"

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_SKIPPED"
  echo "output: $output"
  echo "status: $status"
  assert_output_not_exists

  run /bin/bash -c "dokku checks:enable $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_DISABLED"
  echo "output: $output"
  echo "status: $status"
  assert_output_not_exists

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_SKIPPED"
  echo "output: $output"
  echo "status: $status"
  assert_output_not_exists
}

@test "(checks) checks:disable -> checks:skip" {
  run /bin/bash -c "dokku checks:disable $TEST_APP web,worker,urgentworker,notifications"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_DISABLED"
  echo "output: $output"
  echo "status: $status"
  assert_output "web,worker,urgentworker,notifications"

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_SKIPPED"
  echo "output: $output"
  echo "status: $status"
  assert_output_not_exists

  run /bin/bash -c "dokku checks:skip $TEST_APP urgentworker,worker"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_SKIPPED"
  echo "output: $output"
  echo "status: $status"
  assert_output "urgentworker,worker"

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_DISABLED"
  echo "output: $output"
  echo "status: $status"
  assert_output "web,notifications"
}

@test "(checks) checks:skip" {
  run /bin/bash -c "dokku checks:skip $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_SKIPPED"
  echo "output: $output"
  echo "status: $status"
  assert_output "_all_"
}

@test "(checks) checks:skip -> checks:enable" {
  run /bin/bash -c "dokku checks:skip $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_SKIPPED"
  echo "output: $output"
  echo "status: $status"
  assert_output "_all_"

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_DISABLED"
  echo "output: $output"
  echo "status: $status"
  assert_output_not_exists

  run /bin/bash -c "dokku checks:enable $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_SKIPPED"
  echo "output: $output"
  echo "status: $status"
  assert_output_not_exists

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_DISABLED"
  echo "output: $output"
  echo "status: $status"
  assert_output_not_exists
}

@test "(checks) checks:skip -> checks:disable" {
  run /bin/bash -c "dokku checks:skip $TEST_APP web,worker,urgentworker,notifications"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_SKIPPED"
  echo "output: $output"
  echo "status: $status"
  assert_output "web,worker,urgentworker,notifications"

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_DISABLED"
  echo "output: $output"
  echo "status: $status"
  assert_output_not_exists

  run /bin/bash -c "dokku checks:disable $TEST_APP urgentworker,worker"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_DISABLED"
  echo "output: $output"
  echo "status: $status"
  assert_output "urgentworker,worker"

  run /bin/bash -c "dokku config:get $TEST_APP DOKKU_CHECKS_SKIPPED"
  echo "output: $output"
  echo "status: $status"
  assert_output "web,notifications"
}

@test "(checks) checks:run" {
  run /bin/bash -c "dokku ps:scale $TEST_APP worker=1"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run deploy_app
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku checks:run $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku checks:run $TEST_APP web"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku checks:run $TEST_APP web,worker"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku checks:run $TEST_APP worker.1"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku checks:run $TEST_APP web2"
  echo "output: $output"
  echo "status: $status"
  assert_failure

  run /bin/bash -c "dokku checks:run $TEST_APP web.2"
  echo "output: $output"
  echo "status: $status"
  assert_failure
}

@test "(checks) checks:disable -> app start with missing containers" {
  run /bin/bash -c "dokku ps:scale $TEST_APP worker=1"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run deploy_app
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku checks:disable $TEST_APP worker"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku ps:stop $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku cleanup"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku ps:start $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success
}

@test "(checks) checks:templated" {
  run /bin/bash -c "dokku config:set $TEST_APP HEALTHCHECK_ENDPOINT=/healthcheck"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run deploy_app nodejs-express dokku@$DOKKU_DOMAIN:$TEST_APP template_checks_file
  echo "output: $output"
  echo "status: $status"
  assert_output_contains "/healthcheck"
  assert_success
}

@test "(checks) listening checks" {
  if [[ "$TERM_PROGRAM" == "vscode" ]]; then
    skip "environment must be running in the host namespace"
  fi

  run /bin/bash -c "dokku config:set $TEST_APP ALT_PORT=5001"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run deploy_app
  echo "output: $output"
  echo "status: $status"
  assert_failure
  assert_output_contains "Failure in name='port listening check': container listening on expected IPv4 interface with an unexpected port: expected=5000 actual=5001"
  assert_output_contains "Running healthcheck name='port listening check' attempts=3 port=5000 retries=2 timeout=5 type='listening' wait=5"
}
