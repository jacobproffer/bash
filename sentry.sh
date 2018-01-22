#!/bin/bash
sentry() {
  # check for peeping eyes
  log stream --predicate 'eventMessage contains "Authentication"'
}
sentry