#!/usr/bin/env bats

load test_helper

setup() {
  global_setup
}

teardown() {
  global_teardown
}

@test "(apps) apps:clone" {
  run deploy_app
  echo "output: $output"
  echo "status: $status"
  assert_success
  run /bin/bash -c "dokku apps:clone $TEST_APP great-test-name"
  echo "output: $output"
  echo "status: $status"
  assert_success
  run /bin/bash -c "dokku apps:list | grep $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success
  run /bin/bash -c "curl --silent --write-out '%{http_code}\n' $(dokku url great-test-name) | grep 404"
  echo "output: $output"
  echo "status: $status"
  assert_output_not_exists
  run /bin/bash -c "dokku --force apps:destroy great-test-name"
  echo "output: $output"
  echo "status: $status"
  assert_success
}

@test "(apps) apps:clone (no app)" {
  run /bin/bash -c "dokku apps:create $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku buildpacks:add $TEST_APP https://github.com/heroku/heroku-buildpack-ruby.git"
  echo "output: $output"
  echo "status: $status"
  assert_success
  run /bin/bash -c "dokku git:set $TEST_APP deploy-branch SOME_BRANCH_NAME"
  echo "output: $output"
  echo "status: $status"
  assert_success
  run /bin/bash -c "dokku network:set $TEST_APP attach-post-create test-network"
  echo "output: $output"
  echo "status: $status"
  assert_success
  run /bin/bash -c "dokku nginx:set $TEST_APP  bind-address-ipv4 127.0.0.1"
  echo "output: $output"
  echo "status: $status"
  assert_success
  run /bin/bash -c "dokku resource:limit --memory 100 $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku apps:clone $TEST_APP great-test-name"
  echo "output: $output"
  echo "status: $status"
  assert_success
  run /bin/bash -c "dokku apps:list | grep $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku buildpacks:report great-test-name --buildpacks-list"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output "https://github.com/heroku/heroku-buildpack-ruby.git"
  run /bin/bash -c "dokku domains:report great-test-name --domains-app-vhosts"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output "great-test-name.$DOKKU_DOMAIN"
  run /bin/bash -c "dokku git:report great-test-name --git-deploy-branch"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output "SOME_BRANCH_NAME"
  run /bin/bash -c "dokku network:report great-test-name --network-attach-post-create"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output "test-network"
  run /bin/bash -c "dokku nginx:report great-test-name --nginx-bind-address-ipv4"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output "127.0.0.1"
  run /bin/bash -c "dokku resource:report great-test-name --resource-_default_.limit.memory"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output "100"

  run /bin/bash -c "dokku --force apps:destroy great-test-name"
  echo "output: $output"
  echo "status: $status"
  assert_success
}

@test "(apps) apps:clone ssl-app" {
  skip "this test always failed and requires changes in dokku to support detected vs specified functionality"
  run /bin/bash -c "dokku apps:create $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success
  run /bin/bash -c "dokku ports:set $TEST_APP https:443:5000"
  echo "output: $output"
  echo "status: $status"
  assert_success
  run /bin/bash -c "dokku config:set --no-restart $TEST_APP DOKKU_PROXY_SSL_PORT=443"
  echo "output: $output"
  echo "status: $status"
  assert_success
  run deploy_app
  echo "output: $output"
  echo "status: $status"
  assert_success
  run /bin/bash -c "dokku apps:clone $TEST_APP app-without-ssl"
  echo "output: $output"
  echo "status: $status"
  assert_success
  run /bin/bash -c "dokku --quiet ports:list app-without-ssl | xargs"
  echo "output: $output"
  echo "status: $status"
  assert_output "http 80 5000"
  run /bin/bash -c "dokku config:get app-without-ssl DOKKU_PROXY_SSL_PORT"
  echo "output: $output"
  echo "status: $status"
  assert_output_not_exists
  run /bin/bash -c "dokku --force apps:destroy app-without-ssl"
  echo "output: $output"
  echo "status: $status"
  assert_success
}

@test "(apps) apps:clone --skip-deploy" {
  run deploy_app
  echo "output: $output"
  echo "status: $status"
  assert_success
  run /bin/bash -c "dokku apps:clone --skip-deploy $TEST_APP great-test-name"
  echo "output: $output"
  echo "status: $status"
  assert_success
  run [ -d /home/dokku/great-test-name/tls ]
  assert_failure
  run [ -f /home/dokku/great-test-name/VHOST ]
  assert_success
  run /bin/bash -c "dokku url great-test-name"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output "http://great-test-name.$DOKKU_DOMAIN"
  run /bin/bash -c "dokku url $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output "http://$TEST_APP.$DOKKU_DOMAIN"
  assert_http_localhost_response "http" "$TEST_APP.$DOKKU_DOMAIN" "80" "/hello"
  assert_http_localhost_response "http" "great-test-name.dokku.me" "80" "/hello" "" "404"
  run /bin/bash -c "dokku --force apps:destroy great-test-name"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_http_localhost_response "http" "$TEST_APP.$DOKKU_DOMAIN" "80" "/hello"
}

@test "(apps) apps:clone --ignore-existing" {
  run deploy_app
  echo "output: $output"
  echo "status: $status"
  assert_success
  run /bin/bash -c "dokku apps:create great-test-name"
  echo "output: $output"
  echo "status: $status"
  assert_success
  run /bin/bash -c "dokku apps:clone --ignore-existing $TEST_APP great-test-name"
  echo "output: $output"
  echo "status: $status"
  assert_success
  run /bin/bash -c "dokku --force apps:destroy great-test-name"
  echo "output: $output"
  echo "status: $status"
  assert_success
}
