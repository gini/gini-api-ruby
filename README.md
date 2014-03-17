<img src="https://www.gini.net/wp-content/uploads/2014/02/Gini-API_logo.svg" width="222" alt="Gini API logo" />

# Gini API Ruby client

[![Build Status](https://travis-ci.org/gini/gini-api-ruby.png)](https://travis-ci.org/gini/gini-api-ruby)
[![Code Climate](https://codeclimate.com/github/gini/gini-api-ruby.png)](https://codeclimate.com/github/gini/gini-api-ruby)
[![Coverage Status](https://coveralls.io/repos/gini/gini-api-ruby/badge.png)](https://coveralls.io/r/gini/gini-api-ruby)
[![Gem Version](https://badge.fury.io/rb/gini-api.png)](http://badge.fury.io/rb/gini-api)

## Resources

- Gini API overview: [https://www.gini.net/api/](https://www.gini.net/api/)
- Gini API documentation: [http://developer.gini.net/gini-api/](http://developer.gini.net/gini-api/)
- Issue tracker: [https://github.com/gini/gini-api-ruby/issues](https://github.com/gini/gini-api-ruby/issues)

## Installation

```
gem install gini-api
```

## Usage examples

Some code snippets to explain the usage of the API client. Please refer to the docs for a complete list of available classes and methods.

### Initialize API object and setup authorization

gini-api-ruby supports two authentication mechanisms:

- authentication code
- username/password

If you are planning to integrate gini-api-ruby into your ruby it is highly recommended to acquire the auth_code yourself and pass it to the login method.
The authentication flow is described in detail in the official [API docs](http://developer.gini.net/gini-api/html/guides/oauth2.html#server-side-flow).

```ruby
require 'gini-api'

api = Gini::Api::Client.new(
  client_id: 'my_client_id',
  client_secret: 'my_client_secret'
)

# auth_code (has been extracted outside of gini-api-ruby)
api.login('1234567890')

# username/password
api.login('user@example.com', 'password')
```

### Upload

```ruby
doc = api.upload('/tmp/my_doc.pdf')
# => Gini::Api::Document
doc.id
# => "123456789-abcd-ef12-000000000000"
doc.progress
# => "COMPLETED"
```

### List

```ruby
list = api.list(limit: 20)
# => Gini::Api::DocumentSet
list.total
# => 15
list.documents
# => [Gini::Api::Document, Gini::Api::Document, ...]
list.each do { |doc| puts doc.id }
# => 1234567890-abc, 0987654321-cba, ...
```

### Get

```ruby
doc = api.get('123456789-abcd-ef12-000000000000')
# => Gini::Api::Document
doc.name
# => test.pdf
```

### Delete

```ruby
api.delete('123456789-abcd-ef12-000000000000')
# => true
```

### Search

```ruby
search = api.search('Telekom', type: 'invoice')
# => Gini::Api::DocumentSet
search.total
# => 5
search.documents
# => [Gini::Api::Document, Gini::Api::Document, ...]
search.each do { |doc| puts doc.id }
# => 1234567890-abc, 0987654321-cba, ...
```

### Pages

```ruby
doc = api.get('123456789-abcd-ef12-000000000000')
# => Gini::Api::Document
doc.pages.length
# => 1
doc.pages[0][:'1280x1810']
# => "https://api.gini.net/documents/123456789-abcd-ef12-000000000000/pages/1/1280x1810"
```

### Layout

```ruby
doc.layout.to_json
# => JSON string
doc.layout.to_xml
# => XML string
```

### Document source

Optimized document after it has been processed (`deskewed`, `optimized`, ...).

```ruby
File.open('/tmp/processed_file.pdf', 'w') { |f| f.write(doc.processed) }
```

### Extractions

```ruby
doc.extractions.amountToPay
# => {:entity=>"amount", :value=>"10.00:EUR", :box=>{:top=>2176.0, :left=>2000.0, :width=>173.0, :height=>50.0, :page=>1}, :candidates=>"amounts"}
doc.extractions[:amountToPay] # Shortcut to get extraction value
# => "10.00:EUR"
doc.extractions.candidates[:dates]
# => Array of all found candidates
doc.extractions.raw
# => {:extractions=>{...
```

### Submitting feedback

```ruby
doc.submit_feedback(:bic, 'XXXXXXXX')
# => nil
doc.submit_feedback(:unknownlabel, 'XXXXXXX')
# => raises Gini::Api::DocumentError
```

## Exceptions / Error handling

A set of custom exceptions is available if API operations fail to complete. In most cases the raised exception objects contain additional information in instance variables prefixed `api_`. Eg:

```ruby
begin
  api.login('user@example.com', 'invalid_password')
rescue Gini::Api::OAuthError => e
  puts e.message
  # => Error message supplied when exception was raised
  puts e.api_error
  # => POST https://api.gini.net/documents/abc-123 : 500 - ERROR_MESSAGE (reqId: OPTIONAL_REQUEST_ID)
  puts e.api_status
  # => 500
  puts e.api_url
  # => https://api.gini.net/documents/abc-123
  puts e.method
  # => POST
  puts e.api_message
  # => ERROR MESSAGE
  puts e.api_request_id
  # => OPTIONAL_REQUEST_ID
end
```

Please keep in mind that the amount of availabe instance variables differs depending on the error situation. For details please refer to the [Gini::Api::Error class](Gini/Api/Error.html).

## Developers

### Getting started

```
git clone https://github.com/gini/gini-api-ruby.git
cd gini-api-ruby
bundle
rake -T
```

### Contributing

It's awesome that you consider contributing to gini-api-ruby. Here's how it's done:

1. Fork repository on [Github](https://github.com/gini/gini-api-ruby)
2. Create a topic/feature branch
3. Write code AND tests
4. Update documentation if necessary
5. Open a pull request

### Generate local documentation

```
rake yard
Files:          10
Modules:         3 (    0 undocumented)
Classes:        12 (    0 undocumented)
Constants:       2 (    0 undocumented)
Methods:        29 (    0 undocumented)
 100.00% documented

open doc/index.html
```

### Tests

The tests are divided into unit and integration tests. The integration tests will contact the 'real' API service and trigger specific actions.

#### Unit tests

```
rake spec:unit
/Users/dkerwin/.rvm/rubies/ruby-2.0.0-p195/bin/ruby -S rspec spec/gini-api/client_spec.rb spec/gini-api/document/extraction_spec.rb
spec/gini-api/document/layout_spec.rb spec/gini-api/document_spec.rb spec/gini-api/error_spec.rb spec/gini-api/oauth_spec.rb
......................................................................

Finished in 0.12666 seconds
70 examples, 0 failures
```

#### Integration tests

Please note that you must specify you API credentials as environment variables.

```
GINI_CLIENT_ID=***** GINI_CLIENT_SECRET=***** GINI_API_USER=***** GINI_API_PASS=***** rake spec:integration
/Users/dkerwin/.rvm/rubies/ruby-2.0.0-p195/bin/ruby -S rspec spec/integration/api_spec.rb
..........

Finished in 31.3 seconds
13 examples, 0 failures, 0 pending
```

#### All-in-one

```
GINI_CLIENT_ID=***** GINI_CLIENT_SECRET=***** GINI_API_USER=***** GINI_API_PASS=***** rake spec:all
```

#### Code coverage

Code coverage reports are automatically created. The reports can be found in `coverage/`.

```
rake spec:unit
..............................................................................................................

Finished in 0.79855 seconds
110 examples, 0 failures

Randomized with seed 49394

Coverage report generated for RSpec to xxx/Code/gini-api-ruby/coverage. 274 / 274 LOC (100.0%) covered.
Coverage report Rcov style generated for RSpec to xxx/Code/gini-api-ruby/coverage/rcov
```

#### Continous Integration

It's possible to create jUnit compatible test reports that can be used by tools like [Jenkins](http://jenkins-ci.org/). The generated XML files can be found in `spec/reports`. Simply modify your rake call:

```
rake ci:setup:rspec spec:all
```

## License

The MIT License (MIT)

Copyright (c) 2014 Gini GmbH

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
