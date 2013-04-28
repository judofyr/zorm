# Zorm

Zorm is an Object-Relational Mapper in Ruby that separates your business
models from the persistance layer. As boring as it may sound, this gives us
some interesting features:

* Use the same model to represent the same data, regardless of whether it comes
  from your main data store (e.g. PostgreSQL) or from your search engine
  (e.g. ElasticSearch).

* Store different parts of a model in different data stores.

* Gives you full control over how you access your data, yet makes it possible
  to create abstractions so you don't have to repeat yourself.

* You can test your models without connecting to any data store.

Zorm is lightweight: it's only the glue between your models and the data
store, and uses libraries like Sequel, ActiveRecord, MongoDB-Ruby and
Redis-Ruby to do the hard work.

## Status

Zorm is currently in alpha. We're still trying to figure out how everything
should work together so major changes are happening all the time.

The project is [hosted on GitHub](https://github.com/judofyr/zorm) and
available under the [MIT license](http://github.com/judofyr/zorm/blob/master/LICENSE).

