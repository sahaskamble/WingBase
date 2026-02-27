users ──────────────────────────────────────────┐
  │                                             │
  ├──< chats >── participants (many-to-many)    │
  │      │                                      │
  │      └──< messages >── senderId             │
  │             │                               │
  │             └── replyTo (self relation)     │
  │                                             │
  ├── presence (one-to-one)                     │
  ├── contacts (one-to-many)                    │
  ├── calls                                     │
  └── status                                    │
        └───────────────────────────────────────┘

