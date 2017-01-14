## Reqeust-Response Recorder using goreplay ##


### Run it ###

``` shell
bundle install
gor --input-file [your request-response file] \
    --output-http "http://example.com" \
    --middleware "./req_resp_recorder.rb [output_dir]"
```

### Analyze ###

``` shell
bundle exec ruby result_analyzer.rb [input_dir]
```
