# Use an official Ruby runtime as a parent image
FROM ruby:2.7.3

# Set the working directory in the container to /app
WORKDIR /app

# Copy the Gemfile and Gemfile.lock into the container at /app
COPY Gemfile Gemfile.lock ./

# Install dependencies using Bundler
RUN gem install bundler && bundle install

# Copy the rest of the application code into the container at /app
COPY . .

# Define a default command to run when the container starts
CMD ["bundle", "exec", "ruby", "app/trade.rb"]

# Allow the default command to be overridden by passing a command as an argument
ENTRYPOINT ["/bin/sh", "-c"]
