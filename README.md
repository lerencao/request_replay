## Reqeust-Response Recorder using goreplay ##


### Run it ###

``` shell
bundle install
vim .env
gor --input-raw :3000 \
    --input-raw-track-response \
    --output-http "http://example.com" \
    --middleware "$(which ruby) ./req_resp_recorder.rb" \
    --http-disallow-url /nonsense \
    --stats \
    --verbose
```

### Analyze ###

``` shell
bundle exec ruby result_analyzer.rb [input_dir]
```

### TODO ###

rewrite it in go, and make it a plugin of goreplay
