# Dev MCP Server

This is a basic MCP server for developing applications using ruby on rails.

It assumes you have a standard Rails application structure.

## Getting Started

Probably you don't want to run this server as it is.  The best way to use it is to fork the repository, add your business logic and your development tools, and then run it.


## MCP Resources

Add your files to `docs/resources/`.  The server will automatically serve these files as resources.


How to run it:

```bash
git clone server.git
cd server
bundle install
rails s -p 2603
```

Then you can access the server at `http://localhost:2603`.

Now go to your favourite AI development tool and connect to the server using the URL `http://localhost:2603`.  No authentication is required.
