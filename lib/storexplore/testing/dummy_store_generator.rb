# -*- coding: utf-8 -*-
#
# dummy_store_generator
#
# Copyright (c) 2012, 2013 by Philippe Bourgau. All rights reserved.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3.0 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301  USA

require "fileutils"

class Array

  def contains?(other)
    other.all? do |x|
      include?(x)
    end
  end

  def stringify
    map &:to_s
  end
end

class Hash

  def contains?(other)
    other.all? do |key, value|
      include?(key) && self[key] == value
    end
  end

  def without(keys)
    reject do |key, value|
      keys.include?(key)
    end
  end

  unless method_defined?("stringify_keys")
    def stringify_keys
      result = {}
      self.each do |key, value|
        result[key.to_s] = value
      end
      result
    end
  end

  def internalize_keys
    result = {}
    self.each do |key, value|
      result[key.intern] = value
    end
    result
  end
end

module Storexplore
  module Testing

    class DummyStore

      def self.root_dir
        raise StandardError.new('You need to configure a dummy store generation root directory with Storexplore::Testing::DummyStore.configure_root_dir') if @root_dir.nil?
        @root_dir
      end

      def self.configure_root_dir(root_dir)
        @root_dir = root_dir
      end

      def self.open(store_name)
        new(root_path(store_name), store_name)
      end

      def self.uri(store_name)
        "file://#{root_path(store_name)}"
      end

      def self.wipe_out
        FileUtils.rm_rf(root_dir)
      end
      def self.wipe_out_store(store_name)
        FileUtils.rm_rf(root_path(store_name))
      end

      def uri
        "file://#{@path}"
      end

      attr_reader :name

      def categories
        _name, categories, _items, _attributes = read
        categories.map do |category_name|
          DummyStore.new("#{absolute_category_dir(category_name)}/index.html", category_name)
        end
      end
      def category(category_name)
        short_category_name = short_name(category_name)
        add([short_category_name], [], {})
        DummyStore.new("#{absolute_category_dir(short_category_name)}/index.html", category_name)
      end
      def remove_category(category_name)
        short_category_name = short_name(category_name)
        remove([short_category_name], [], [])
        FileUtils.rm_rf(absolute_category_dir(short_category_name))
      end

      def items
        _name, _categories, items, _attributes = read
        items.map do |item_name|
          DummyStore.new(absolute_item_file(item_name), item_name)
        end
      end
      def item(item_name)
        short_item_name = short_name(item_name)
        add([], [short_item_name], {})
        DummyStore.new(absolute_item_file(short_item_name), item_name)
      end
      def remove_item(item_name)
        short_item_name = short_name(item_name)
        remove([], [short_item_name], [])
        FileUtils.rm_rf(absolute_item_file(short_item_name))
      end

      def attributes(*args)
        return add_attributes(args[0]) if args.size == 1

        _name, _categories, _items, attributes = read
        attributes.internalize_keys
      end
      def add_attributes(values)
        add([], [], values.stringify_keys)
      end
      def remove_attributes(*attribute_names)
        remove([], [], attribute_names.stringify)
      end

      def generate(count = 1)
        DummyStoreGenerator.new([self], count)
      end

      private

      def self.root_path(store_name)
        "#{root_dir}/#{store_name}/index.html"
      end

      def initialize(path, name)
        @path = path
        @name = name
        if !File.exists?(path)
          write(name, [], [], {})
        end
      end

      def short_name(full_name)
        full_name[0..20]
      end

      def absolute_category_dir(category_name)
        "#{File.dirname(@path)}/#{relative_category_dir(category_name)}"
      end
      def relative_category_dir(category_name)
        category_name
      end

      def absolute_item_file(item_name)
        "#{File.dirname(@path)}/#{relative_item_file(item_name)}"
      end
      def relative_item_file(item_name)
        "#{item_name}.html"
      end

      def add(extra_categories, extra_items, extra_attributes)
        name, categories, items, attributes = read

        if !categories.contains?(extra_categories) || !items.contains?(extra_items) || !attributes.contains?(extra_attributes)
          write(name, categories + extra_categories, items + extra_items, attributes.merge(extra_attributes))
        end
      end
      def remove(wrong_categories, wrong_items, wrong_attributes)
        name, categories, items, attributes = read
        write(name, categories - wrong_categories, items - wrong_items, attributes.without(wrong_attributes))
      end

      def write(name, categories, items, attributes)
        FileUtils.mkdir_p(File.dirname(@path))
        IO.write(@path, content(name, categories, items, attributes))
      end

      def content(name, categories, items, attributes)
        (["<!DOCTYPE html>",
          "<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\" /></head>",
          "<body><h1>#{name}</h1><div id=\"categories\"><h2>Categories</h2><ul>"] +
         categories.map {|cat|  "<li><a class=\"category\" href=\"#{relative_category_dir(cat)}/index.html\">#{cat}</a></li>" } +
         ['</ul></div><div id="items"><h2>Items</h2><ul>']+
         items.map      {|item| "<li><a class=\"item\" href=\"#{relative_item_file(item)}\">#{item}</a></li>" } +
         ['</ul></div><div id="attributes"><h2>Attributes</h2><ul>']+
         attributes.map {|key, value| "<li><span id=\"#{key}\">#{value}</span></li>" } +
         ["</ul></div></body></html>"]).join("\n")
      end

      def read
        parse(IO.readlines(@path))
      end

      def parse(lines)
        name = ""
        categories = []
        items = []
        attributes = {}
        lines.each do |line|
          name_match = /<h1>([^<]+)<\/h1>/.match(line)
          sub_match = /<li><a class=\"([^\"]+)\" href=\"[^\"]+.html\">([^<]+)<\/a><\/li>/.match(line)
          attr_match = /<li><span id=\"([^\"]+)\">([^<]+)<\/span><\/li>/.match(line)

          if !!name_match
            name = name_match[1]
          elsif !!sub_match
            case sub_match[1]
            when "category" then categories << sub_match[2]
            when "item" then items << sub_match[2]
            end
          elsif !!attr_match
            attributes[attr_match[1]] = attr_match[2]
          end
        end
        [name, categories, items, attributes]
      end
    end

    class DummyStoreGenerator
      def initialize(pages, count = 1)
        @pages = pages
        @count = count
      end

      def and(count)
        @count = count
        self
      end

      def categories
        dispatch(:category)
      end
      alias_method :category, :categories

      def items
        dispatch(:item).attributes
      end
      alias_method :item, :items

      def attributes(options = {})
        @pages.map do |page|
          attributes = FactoryGirl.attributes_for(:item, options.merge(name: page.name))
          page.attributes(attributes.without([:name]))
        end
      end

      private

      def dispatch(message)
        sub_pages = @pages.map do |page|
          @count.times.map do
            page.send(message, FactoryGirl.generate("#{message}_name".intern))
          end
        end
        DummyStoreGenerator.new(sub_pages.flatten)
      end
    end
  end
end