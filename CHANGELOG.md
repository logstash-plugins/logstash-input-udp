## 3.5.0
  - Added ECS v8 support as an alias to the ECS v1 implementation

## 3.4.1
  - [DOC] Fixed typo in code sample [#54](https://github.com/logstash-plugins/logstash-input-udp/pull/54)

## 3.4.0
  - Added ECS compatibility mode (`disabled` and `v1`) to rename ip source address in a ECS compliant name [#50](https://github.com/logstash-plugins/logstash-input-udp/pull/50)
  - Fixed integration tests for IPv6 downgrading Docker to version 2.4 [#51](https://github.com/logstash-plugins/logstash-input-udp/pull/51)

## 3.3.4
  - Fixed input workers exception handling and shutdown handling [#44](https://github.com/logstash-plugins/logstash-input-udp/pull/44)

## 3.3.3
  - Work around jruby/jruby#5148 by cloning messages on jruby 9k, therefore resizing the underlying byte buffer

## 3.3.2
  - Fix missing require for the ipaddr library.

## 3.3.1
  - Docs: Set the default_codec doc attribute.

## 3.3.0
  - Add metrics support for events, operations, connections and errors produced during execution. #34
  - Fix support for IPv6 #31

## 3.2.1
  - Code cleanup. See https://github.com/logstash-plugins/logstash-input-udp/pull/33

## 3.2.0
  - Clone codec per worker. See https://github.com/logstash-plugins/logstash-input-udp/pull/32

## 3.1.3
  - Update gemspec summary

## 3.1.2
  - Fix some documentation issues

## 3.1.0
  - Add "receive_buffer_bytes" config setting to optionally set socket receive buffer size

## 3.0.3
  - fix performance regression calling IO.select for every packet #21

## 3.0.2
  - Relax constraint on logstash-core-plugin-api to >= 1.60 <= 2.99

## 3.0.1
  - Republish all the gems under jruby.
## 3.0.0
  - Update the plugin to the version 2.0 of the plugin api, this change is required for Logstash 5.0 compatibility. See https://github.com/elastic/logstash/issues/5141
# 2.0.5
  - Depend on logstash-core-plugin-api instead of logstash-core, removing the need to mass update plugins on major releases of logstash
# 2.0.4
  - New dependency requirements for logstash-core for the 5.0 release
## 2.0.2
 - Adapt the test style to be able to run within the context of the LS
   core default plugins test (integration)

## 2.0.0
 - Plugins were updated to follow the new shutdown semantic, this mainly allows Logstash to instruct input plugins to terminate gracefully, 
   instead of using Thread.raise on the plugins' threads. Ref: https://github.com/elastic/logstash/pull/3895
 - Dependency on logstash-core update to 2.0

