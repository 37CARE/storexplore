# -*- encoding: utf-8 -*-
#
# dummy_store_api_spec.rb
#
# Copyright (c) 2011, 2012, 2013 by Philippe Bourgau. All rights reserved.
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

require 'spec_helper'

module Storexplore
  module Testing

    describe "DummyStoreApi", slow: true do
      include ApiSpecMacros

      it_should_behave_like_any_store_items_api

      DEFAULT_STORE_NAME = "www.spec-store.com"

      def generate_store(store_name = DEFAULT_STORE_NAME, item_count = 3)
        DummyStore.wipe_out_store(store_name)
        @store_generator = DummyStore.open(store_name)
        @store_generator.generate(3).categories.and(3).categories.and(item_count).items
        @store = new_store(store_name)
      end

      def new_store(store_name = DEFAULT_STORE_NAME)
        Api.browse(DummyStore.uri(store_name))
      end

      it "should not truncate long item names" do
        @store_generator.
          category(cat_name = "extra long category name").
          category(sub_cat_name = "extra long sub category name").
          item(item_name = "super extra long item name").generate().attributes

        category = new_store.categories.find {|cat| cat_name.start_with?(cat.title)}
        expect(category.attributes[:name]).to eq cat_name

        sub_category = category.categories.find {|sub_cat| sub_cat_name.start_with?(sub_cat.title)}
        expect(sub_category.attributes[:name]).to eq sub_cat_name

        item = sub_category.items.find {|it| item_name.start_with?(it.title)}
        expect(item.attributes[:name]).to eq item_name
      end

      it "should use constant memory" do
        FEW = 1
        MANY = 100

        warm_up_measure = memory_usage_for_items(FEW)
        few_inputs_memory = memory_usage_for_items(FEW)
        many_inputs_memory = memory_usage_for_items(MANY)

        expect(many_inputs_memory).to be <= few_inputs_memory * 1.25
      end

      def memory_usage_for_items(item_count)
        generate_store(store_name = "www.spec-perf-store.com", item_count)
        memory_peak_of do
          walk_store(store_name)
        end
      end

      def memory_peak_of
        peak_usage = 0
        finished = false

        initial_usage = current_living_objects
        profiler = Thread.new do
          while not finished
            peak_usage = [peak_usage, current_living_objects].max
            sleep(0.01)
          end
        end

        yield

        finished = true
        profiler.join

        peak_usage - initial_usage
      end

      def current_living_objects
        object_counts = ObjectSpace.count_objects
        object_counts[:TOTAL] - object_counts[:FREE]
      end

      def walk_store(store_name)
        new_store(store_name).categories.each do |category|
          register(category)

          category.categories.each do |sub_category|
            register(sub_category)

            sub_category.items.each do |item|
              register(item)
            end
          end
        end
      end

      def register(store_node)
        @title = store_node.title
        @attributes = store_node.attributes
        GC.start
      end

    end

  end
end
