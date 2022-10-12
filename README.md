# Example code to show how to return interfaces and union types with AppSync

## Deploy

* ```terraform init```
* ```terraform apply```

## Usage

### Interface

There are 2 types of users implementing the same interface.

```graphql
type AdminUser implements User {
	id: ID!
	permissions: [String!]!
}

type NormalUser implements User {
	id: ID!
}

type Query {
	allUsers: [User!]!
}

interface User {
	id: ID!
}
```

```graphql
query MyQuery {
  allUsers {
    id
    __typename
    ... on AdminUser {
      id
      permissions
    }
    ... on NormalUser {
      id
    }
  }
}
```

```json
{
  "data": {
    "allUsers": [
      {
        "id": "user1",
        "__typename": "NormalUser"
      },
      {
        "id": "user2",
        "__typename": "NormalUser"
      },
      {
        "id": "user3",
        "__typename": "AdminUser",
        "permissions": [
          "create-users"
        ]
      }
    ]
  }
}
```

### Union types

The search can return Files and Documents:

```graphql
type Document {
	id: ID!
	contents: String!
}

type File {
	id: ID!
	filename: String!
	url: String!
}

type Query {
	search(text: String!): [SearchResult!]!
}

union SearchResult = File | Document 
```

```graphql
query MyQuery {
  search(text: "d") {
    __typename
    ... on File {
      id
      url
      filename
    }
    ... on Document {
      id
      contents
    }
  }
}
```

```json
{
  "data": {
    "search": [
      {
        "__typename": "Document",
        "id": "doc2",
        "contents": "super important document"
      },
      {
        "__typename": "Document",
        "id": "doc1",
        "contents": "important document"
      },
      {
        "__typename": "File",
        "id": "file1",
        "url": "example.com/schemas.pdf",
        "filename": "schemas.pdf"
      }
    ]
  }
}
```

## Cleanup

* ```terraform destroy```
