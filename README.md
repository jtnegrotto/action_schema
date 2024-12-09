# ActionSchema

ActionSchema provides a flexible, Rails-friendly approach to rendering ~and
parsing~ (coming soon) structured data in your controllers.

## Status: Experimental 🚧

**ActionSchema** is currently in early development. Its API is subject to
significant changes. If you do choose to use it, please:

* Lock the version in your Gemfile (e.g. `gem "action_schema", "= 0.1.0"`) 
* Be prepared to update your code as the library evolves
* Refer to the [CHANGELOG](CHANGELOG.md) for updates
* [Report](https://github.com/jtnegrotto/action_schema/issues/new) any issues you encounter to help improve the library

## Installation

Add the gem to your Gemfile:

```bash
bundle add action_schema -v '= 0.1.0'
```

## Usage

### Defining Schemas

#### Inline Schemas

The simplest way to define a schema is inline in your controller action:

```ruby
class UsersController < ApplicationController
  def index
    users = User.all
    render json: schema_for(users) do
      fields :id, :email
      computed(:full_name) { |user| "#{user.first_name} #{user.last_name}" }
    end
  end
end
```

This approach is ideal for quick, one-off schemas. Think of it as a step up from `as_json` with added flexibility and readability.

#### Controller Schemas

For reusable schemas, define them in your controller. This keeps your code DRY and allows schemas to be shared across multiple actions:

```ruby
class UsersController < ApplicationController
  schema :index do
    fields :id, :email
    computed(:full_name) { |user| "#{user.first_name} #{user.last_name}" }
  end

  def index
    users = User.all
    render json: schema_for(users, :index)
  end
end
```

**Tip:** Controller schemas are inherited by subclasses. This makes it easy to define a common schemas in a base controller.

#### Class Schemas

For global schemas, use schema classes:

```ruby
class UserSchema < ActionSchema::Base
  fields :id, :email
  computed(:full_name) { |user| "#{user.first_name} #{user.last_name}" }
end
```

You can use these in your controllers like so:

```ruby
class UsersController < ApplicationController
  def index
    users = User.all
    render json: schema_for(users, UserSchema)
  end
end
```

### Schema Definition DSL

#### Fields

Regular fields are defined using the `field` and `fields` methods:

```ruby
field :id
field :name
field :created_at
field :updated_at
```

or

```ruby
fields :id, :name, :created_at, :updated_at
```

Fields can be conditionally rendered using the `if` and `unless` options:

```ruby
field :email, if: ->(user) { user.email.present? }
field :phone, unless: ->(user) { user.phone.nil? }
```

#### Omitting Fields

You can omit fields using the `omit` method:

```ruby
omit :created_at, :updated_at
```

This can be useful when your schema inherits fields from a superclass, but you
don't need all of them in a particular action.

#### Computed Fields

Computed fields are defined using the `computed` method:

```ruby
computed(:full_name) { |user| "#{user.first_name} #{user.last_name}" }
```

#### Associations

Association schemas are specified using the `association` method, and like
other schemas, these can be defined inline, at the controller level, or in a
schema class.

##### Inline

```ruby
schema do
  fields :id, :email
  association :posts do
    fields :id, :title
  end
end
```

##### Named Schema

```ruby
schema :index do
  fields :id, :email
  association :posts, :post
end

schema :post do
  fields :id, :title
end
```

##### Class Schema

```ruby
class UserSchema < ActionSchema::Base
  fields :id, :email
  association :posts, PostSchema
end

class PostSchema < ActionSchema::Base
  fields :id, :title
end
```

#### Contexts

Computed fields can access contextual data:

```ruby
computed(:is_current_user) { |user, context| user == context[:current_user] }
```

In your controller, you can pass the context to `#schema_for`:

```ruby
render json: schema_for(users, context: { current_user: current_user })
```

Alternatively, you can define the context at the controller level:

```ruby
class UsersController < ApplicationController
  schema_context({ current_user: :current_user })
end
```

Controller-level contexts are inherited, and are merged with contexts defined
in the subclass. Action-level contexts inherit from the controller-level
context, and are similarly merged. More specific contexts take precedence over
less specific ones.

#### Hooks

You can define hooks to run before or after rendering. The `before_render` hook
takes a block that receives the record or collection to be rendered. The
`after_render` hook takes a block that receives the rendered data. Both hooks
allow you to replace the data with a new value using the `transform` method:

```ruby
schema :default do
  fields :id, :email

  before_render do |user|
    user.email.downcase!
  end

  after_render do |data|
    transform({ user: data })
  end
end
```

**Tip:** Keep in mind that hooks are run whether the rendered object is a
single record or a collection. Be sure to handle both cases as necessary.

## Rationale

The main reason that **ActionSchema** exists is that I find serialization in
Rails to be a bit of a pain. While Rails' built-in serialization methods
(`as_json`) are fine for simple cases, they quickly fall apart when you need to
handle anything more complex. On the other hand, many serialization libraries
feel like overkill, requiring too much boilerplate for tasks that should be
straightforward.

I believe that serialization is fundamentally the controller's responsibility.
After all, you can't effectively optimize your queries if you don't know what
data will be used. Integrating serialization into the controller, close to the
query, makes it easier to reason about and ensures a tighter integration
between your data and its representation.

That said, I understand that not everyone shares this view. While
**ActionSchema** provides a seamless API for defining schemas entirely within
controllers, it also supports defining reusable schema classes outside of
controllers for those who prefer a more decoupled approach. My goal is to
strike a balance: to make serialization simple when you need it to be, while
remaining flexible enough to adapt to a variety of use cases and scenarios.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and the created tag, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/jtnegrotto/action_schema.

## License

The gem is available as open source under the terms of the [MIT
License](https://opensource.org/licenses/MIT).
