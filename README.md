[![Build Status](https://travis-ci.org/philou/storexplore.svg?branch=master)](https://travis-ci.org/philou/storexplore) [![Test Coverage](https://codeclimate.com/github/philou/storexplore/badges/coverage.svg)](https://codeclimate.com/github/philou/storexplore) [![Code Climate](https://codeclimate.com/github/philou/storexplore/badges/gpa.svg)](https://codeclimate.com/github/philou/storexplore)

# Storexplore

Transform online stores into APIs !

## Why
Once upon a time, I wanted to create online groceries with great user experience ! That's how I started [mes-courses.fr](https://github.com/philou/mes-courses). Unfortunately, most online groceries don't have APIs, so I resorted to scrapping. Scrapping comes with its (long) list of problems aswell !

* Scrapping code is a mess
* The scrapped html can change at any time
* Scrappers are difficult to test

Refactoring after refactoring, I managed to extract this libary  to define scrappers for an online grocery in a straightforward way (check [auchandirect-scrAPI](https://github.com/philou/auchandirect-scrAPI) for the actual scrapper I was using). A scrapper definition consists of :

* a scrapper definition file
* the selectors for the links
* the selectors for the content you want to capture

As a result of using storexplore for mes-courses, the scrapping code was split between the storexplore gem and my special scrapper definition :

* This made the whole overall code cleaner
* I could write simple and reliable tests
* Most importantly, I could easily keep pace with the changes in the online store html

## Installation

In order to be able to enumerate all items of a store in constant memory,
Storexplore requires Matz Ruby 2.0 for its lazy enumerators.

Add this line to your application's Gemfile:

    gem 'storexplore'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install storexplore

## Usage

The library builds hierarchical APIs on online stores. Stores are typicaly
organized in the following way :

    Store > Categories > ... > Sub Categories > Items

The store is like a root category. Any category, at any depth level can have
both children categories and items. Items cannot have children of any kind.
Both categories and items can have attributes.

All searching of children and attributes is done through mechanize/nokogiri
selectors (css or xpath).

Here is a sample store api declaration :

```ruby
Storexplore::define_api 'dummy-store.com' do

  categories 'a.category' do
    attributes do
      { :name => page.get_one("h1").content }
    end

    categories 'a.category' do
      attributes do
        { :name => page.get_one("h1").content }
      end

      items 'a.item' do
        attributes do
          {
            :name => page.get_one('h1').content,
            :brand => page.get_one('#brand').content,
            :price => page.get_one('#price').content.to_f,
            :image => page.get_one('#image').content,
            :remote_id => page.get_one('#remote_id').content
          }
        end
      end
    end
  end
end
```

This build a hierarchical API on the 'dummy-store.com' online store. This
registers a new api definition that will be used to browse any store which
uri contains 'dummy-store.com'.

Now here is how this API can be accessed to pretty print all its content:

```ruby
Api.browse('http://www.dummy-store.com').categories.each do |category|

  puts "category: #{category.title}"
  puts "attributes: #{category.attributes}"

  category.categories.each do |sub_category|

    puts "  category: #{sub_category.title}"
    puts "  attributes: #{sub_category.attributes}"

    sub_category.items.each do |item|

      puts "    item: #{item.title}"
      puts "    attributes: #{item.attributes}"

    end
  end
end
```

### Testing

Storexplore ships with some dummy store generation utilities. Dummy stores can
be generated to the file system using the Storexplore::Testing::DummyStore and
Storexplore::Testing::DummyStoreGenerator classes. This is particularly useful
while testing.

To use it, add the following, to your spec_helper.rb for example :

```ruby
require 'storexplore/testing'

Storexplore::Testing.config do |config|
  config.dummy_store_generation_dir= File.join(Rails.root, '../tmp')
end
```

It is then possible to generate a store with the following :

```ruby
DummyStore.wipe_out_store(store_name)
@store_generator = DummyStore.open(store_name)
@store_generator.generate(3).categories.and(3).categories.and(item_count).items
```

It is also possibe to add elements with explicit values :

```ruby
@store_generator.
  category(cat_name = "extra long category name").
  category(sub_cat_name = "extra long sub category name").
  item(item_name = "super extra long item name").generate().
    attributes(price: 12.3)
```

Storexplore provides an api definition for dummy stores in
'storexplore/testing/dummy_store_api'. It can be required independently if
needed.

### RSpec shared examples

Storexplore also ships with an rspec shared examples macro. It can be used for
any custom store API definition.

```ruby
require 'storexplore/testing'

describe "MyStoreApi" do
  include Storexplore::Testing::ApiSpecMacros

  it_should_behave_like_any_store_items_api

  ...

end
```

### Testing files to require

* To only get the api definition for a previously generated dummy store, it is enough to require 'storexplore/testing/dummy_store_api'
* To be able to generate and scrap dummy stores, it's needed to require 'storexplore/testing/dummy_store_generator'
* To do all the previous and to use rspec utilities, require 'storexplore/testing'

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
