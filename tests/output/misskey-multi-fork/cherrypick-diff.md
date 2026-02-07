# API Diff Report: base → cherrypick

## Summary

- **Total Changes**: 321
- **Added Endpoints**: 80
- **Removed Endpoints**: 28
- **Modified Endpoints**: 159
- **Added Schemas**: 8
- **Removed Schemas**: 8
- **Modified Schemas**: 38
- **Breaking Changes**: ⚠️ Yes

### Added Endpoints

- **POST /admin/avatar-decorations/copy (post___admin___avatar-decorations___copy)** [admin]
  admin/avatar-decorations/copy
- **POST /admin/avatar-decorations/list-remote (post___admin___avatar-decorations___list-remote)** [admin]
  admin/avatar-decorations/list-remote
- **POST /admin/delete-account (post___admin___delete-account)** [admin]
  admin/delete-account
- **POST /admin/delete-all-files-of-a-user (post___admin___delete-all-files-of-a-user)** [admin]
  admin/delete-all-files-of-a-user
- **POST /admin/emoji/steal (post___admin___emoji___steal)** [admin]
  admin/emoji/steal
- **POST /admin/invite/revoke (post___admin___invite___revoke)** [admin]
  admin/invite/revoke
- **POST /admin/queue/jobs (post___admin___queue___jobs)** [admin]
  admin/queue/jobs
- **POST /admin/queue/promote-jobs (post___admin___queue___promote-jobs)** [admin]
  admin/queue/promote-jobs
- **POST /admin/queue/queue-stats (post___admin___queue___queue-stats)** [admin]
  admin/queue/queue-stats
- **POST /admin/queue/queues (post___admin___queue___queues)** [admin]
  admin/queue/queues
- **POST /admin/queue/remove-job (post___admin___queue___remove-job)** [admin]
  admin/queue/remove-job
- **POST /admin/queue/retry-job (post___admin___queue___retry-job)** [admin]
  admin/queue/retry-job
- **POST /admin/queue/show-job (post___admin___queue___show-job)** [admin]
  admin/queue/show-job
- **POST /admin/queue/show-job-logs (post___admin___queue___show-job-logs)** [admin]
  admin/queue/show-job-logs
- **POST /admin/server-info (post___admin___server-info)** [admin]
  admin/server-info
- **POST /chat/history (post___chat___history)** [chat]
  chat/history
- **POST /chat/messages/create-to-room (post___chat___messages___create-to-room)** [chat]
  chat/messages/create-to-room
- **POST /chat/messages/create-to-user (post___chat___messages___create-to-user)** [chat]
  chat/messages/create-to-user
- **POST /chat/messages/delete (post___chat___messages___delete)** [chat]
  chat/messages/delete
- **POST /chat/messages/react (post___chat___messages___react)** [chat]
  chat/messages/react
- **POST /chat/messages/room-timeline (post___chat___messages___room-timeline)** [chat]
  chat/messages/room-timeline
- **POST /chat/messages/search (post___chat___messages___search)** [chat]
  chat/messages/search
- **POST /chat/messages/show (post___chat___messages___show)** [chat]
  chat/messages/show
- **POST /chat/messages/unreact (post___chat___messages___unreact)** [chat]
  chat/messages/unreact
- **POST /chat/messages/user-timeline (post___chat___messages___user-timeline)** [chat]
  chat/messages/user-timeline
- **POST /chat/read-all (post___chat___read-all)** [chat]
  chat/read-all
- **POST /chat/rooms/create (post___chat___rooms___create)** [chat]
  chat/rooms/create
- **POST /chat/rooms/delete (post___chat___rooms___delete)** [chat]
  chat/rooms/delete
- **POST /chat/rooms/invitations/cancel (post___chat___rooms___invitations___cancel)** [chat]
  chat/rooms/invitations/cancel
- **POST /chat/rooms/invitations/create (post___chat___rooms___invitations___create)** [chat]
  chat/rooms/invitations/create
- **POST /chat/rooms/invitations/ignore (post___chat___rooms___invitations___ignore)** [chat]
  chat/rooms/invitations/ignore
- **POST /chat/rooms/invitations/inbox (post___chat___rooms___invitations___inbox)** [chat]
  chat/rooms/invitations/inbox
- **POST /chat/rooms/invitations/outbox (post___chat___rooms___invitations___outbox)** [chat]
  chat/rooms/invitations/outbox
- **POST /chat/rooms/invitations/reject (post___chat___rooms___invitations___reject)** [chat]
  chat/rooms/invitations/reject
- **POST /chat/rooms/join (post___chat___rooms___join)** [chat]
  chat/rooms/join
- **POST /chat/rooms/joining (post___chat___rooms___joining)** [chat]
  chat/rooms/joining
- **POST /chat/rooms/leave (post___chat___rooms___leave)** [chat]
  chat/rooms/leave
- **POST /chat/rooms/members (post___chat___rooms___members)** [chat]
  chat/rooms/members
- **POST /chat/rooms/mute (post___chat___rooms___mute)** [chat]
  chat/rooms/mute
- **POST /chat/rooms/owned (post___chat___rooms___owned)** [chat]
  chat/rooms/owned
- **POST /chat/rooms/show (post___chat___rooms___show)** [chat]
  chat/rooms/show
- **POST /chat/rooms/update (post___chat___rooms___update)** [chat]
  chat/rooms/update
- **POST /drive/files/attached-chat-messages (post___drive___files___attached-chat-messages)** [drive]
  drive/files/attached-chat-messages
- **POST /drive/files/move-bulk (post___drive___files___move-bulk)** [drive]
  drive/files/move-bulk
- **GET /federation/remote-software (get___federation___remote-software)** [federation]
  federation/remote-software
- **POST /federation/remote-software (post___federation___remote-software)** [federation]
  federation/remote-software
- **POST /flash/gen-token (post___flash___gen-token)** [flash]
  flash/gen-token
- **POST /flash/search (post___flash___search)** [flash]
  flash/search
- **POST /i/auto-delete-settings (post___i___auto-delete-settings)** [account]
  i/auto-delete-settings
- **POST /i/followers-servers (post___i___followers-servers)** [account]
  i/followers-servers
- **POST /i/truncate-account (post___i___truncate-account)**
  i/truncate-account
- **POST /i/update-auto-delete-settings (post___i___update-auto-delete-settings)** [account]
  i/update-auto-delete-settings
- **POST /i/user-group-invites (post___i___user-group-invites)** [account]
  i/user-group-invites
- **POST /notes/bubble-timeline (post___notes___bubble-timeline)** [notes]
  notes/bubble-timeline
- **POST /notes/drafts/count (post___notes___drafts___count)** [notes]
  notes/drafts/count
- **POST /notes/drafts/create (post___notes___drafts___create)** [notes]
  notes/drafts/create
- **POST /notes/drafts/delete (post___notes___drafts___delete)** [notes]
  notes/drafts/delete
- **POST /notes/drafts/list (post___notes___drafts___list)** [notes]
  notes/drafts/list
- **POST /notes/drafts/update (post___notes___drafts___update)** [notes]
  notes/drafts/update
- **POST /notes/events/search (post___notes___events___search)** [notes]
  notes/events/search
- **POST /notes/history (post___notes___history)** [notes]
  notes/history
- **POST /notes/polls/translate (post___notes___polls___translate)** [notes]
  notes/polls/translate
- **POST /notes/show-partial-bulk (post___notes___show-partial-bulk)** [notes]
  notes/show-partial-bulk
- **POST /notes/update (post___notes___update)** [notes]
  notes/update
- **GET /server-info (get___server-info)** [meta]
  server-info
- **POST /server-info (post___server-info)** [meta]
  server-info
- **POST /users/groups/create (post___users___groups___create)** [groups]
  users/groups/create
- **POST /users/groups/delete (post___users___groups___delete)** [groups]
  users/groups/delete
- **POST /users/groups/invitations/accept (post___users___groups___invitations___accept)** [groups]
  users/groups/invitations/accept
- **POST /users/groups/invitations/reject (post___users___groups___invitations___reject)** [groups]
  users/groups/invitations/reject
- **POST /users/groups/invite (post___users___groups___invite)** [groups]
  users/groups/invite
- **POST /users/groups/joined (post___users___groups___joined)** [groups]
  users/groups/joined
- **POST /users/groups/leave (post___users___groups___leave)** [groups]
  users/groups/leave
- **POST /users/groups/owned (post___users___groups___owned)** [groups]
  users/groups/owned
- **POST /users/groups/pull (post___users___groups___pull)** [groups]
  users/groups/pull
- **POST /users/groups/show (post___users___groups___show)** [groups]
  users/groups/show
- **POST /users/groups/transfer (post___users___groups___transfer)** [groups]
  users/groups/transfer
- **POST /users/groups/update (post___users___groups___update)** [groups]
  users/groups/update
- **POST /users/translate (post___users___translate)** [users]
  users/translate
- **POST /verify-email (post___verify-email)** [account]
  verify-email


### Removed Endpoints

- **POST /admin/accounts/pending/list (post___admin___accounts___pending___list)** [admin]
- **POST /admin/accounts/pending/revoke (post___admin___accounts___pending___revoke)** [admin]
- **POST /admin/drive/delete-all-files-of-a-user (post___admin___drive___delete-all-files-of-a-user)** [admin]
- **POST /admin/indie-auth/create (post___admin___indie-auth___create)** [admin]
- **POST /admin/indie-auth/delete (post___admin___indie-auth___delete)** [admin]
- **POST /admin/indie-auth/list (post___admin___indie-auth___list)** [admin]
- **POST /admin/indie-auth/update (post___admin___indie-auth___update)** [admin]
- **POST /admin/queue/promote (post___admin___queue___promote)** [admin]
- **POST /admin/regenerate-user-token (post___admin___regenerate-user-token)** [admin]
- **POST /admin/roles/update-inline-policies (post___admin___roles___update-inline-policies)** [admin]
- **POST /admin/show-user-account-move-logs (post___admin___show-user-account-move-logs)** [admin]
- **POST /admin/sso/create (post___admin___sso___create)** [admin]
- **POST /admin/sso/delete (post___admin___sso___delete)** [admin]
- **POST /admin/sso/list (post___admin___sso___list)** [admin]
- **POST /admin/sso/update (post___admin___sso___update)** [admin]
- **POST /admin/unset-user-mutual-link (post___admin___unset-user-mutual-link)** [admin]
- **POST /admin/update-user-name (post___admin___update-user-name)** [admin]
- **POST /announcement (post___announcement)** [meta]
- **POST /channels/featured-games (post___channels___featured-games)** [channels]
- **POST /i/purge-timeline-cache (post___i___purge-timeline-cache)** [account]
- **GET /meta (get___meta)** [meta]
- **POST /notes/scheduled/cancel (post___notes___scheduled___cancel)** [notes]
- **POST /notes/scheduled/list (post___notes___scheduled___list)** [notes]
- **GET /stats (get___stats)** [meta]
- **POST /users/get-following-birthday-users (post___users___get-following-birthday-users)** [users]
- **POST /users/get-security-info (post___users___get-security-info)** [users]
- **GET /users/get-skeb-status (get___users___get-skeb-status)** [users]
- **POST /users/get-skeb-status (post___users___get-skeb-status)** [users]


### Modified Endpoints

- **POST /admin/abuse-report/notification-recipient/create** **⚠️ BREAKING**: Changed response
- **POST /admin/abuse-report/notification-recipient/show** **⚠️ BREAKING**: Changed response
- **POST /admin/abuse-report/notification-recipient/update** **⚠️ BREAKING**: Changed response
- **POST /admin/abuse-user-reports**: Changed body
- **POST /admin/accounts/create** **⚠️ BREAKING**: Changed response
- **POST /admin/accounts/delete**: Changed body
- **POST /admin/accounts/find-by-email** **⚠️ BREAKING**: Changed response
- **POST /admin/ad/create** **⚠️ BREAKING**: Changed response
- **POST /admin/ad/list**: Changed body
- **POST /admin/announcements/create** **⚠️ BREAKING**: Changed body, response
- **POST /admin/announcements/list**: Changed body
- **POST /admin/announcements/update**: Changed body
- **POST /admin/avatar-decorations/list**: Changed body
- **POST /admin/drive/files**: Changed body
- **POST /admin/drive/show-file** **⚠️ BREAKING**: Changed body, response
- **POST /admin/emoji/add** **⚠️ BREAKING**: Changed body, response
- **POST /admin/emoji/list**: Changed body
- **POST /admin/emoji/list-remote**: Changed body
- **POST /admin/emoji/update**: Changed body
- **POST /admin/meta** **⚠️ BREAKING**: Changed response
- **POST /admin/queue/clear**: Changed body
- **POST /admin/resolve-abuse-user-report**: Changed body
- **POST /admin/roles/assign**: Changed body
- **POST /admin/roles/create** **⚠️ BREAKING**: Changed body, response
- **POST /admin/roles/show** **⚠️ BREAKING**: Changed response
- **POST /admin/roles/update**: Changed body
- **POST /admin/roles/users**: Changed body
- **POST /admin/show-moderation-logs**: Changed body
- **POST /admin/show-user** **⚠️ BREAKING**: Changed response
- **POST /admin/system-webhook/create** **⚠️ BREAKING**: Changed response
- **POST /admin/system-webhook/show** **⚠️ BREAKING**: Changed response
- **POST /admin/system-webhook/test**: Changed body
- **POST /admin/system-webhook/update** **⚠️ BREAKING**: Changed response
- **POST /admin/update-meta**: Changed body
- **POST /admin/update-proxy-account** **⚠️ BREAKING**: Changed response
- **POST /announcements**: Changed body
- **POST /announcements/show** **⚠️ BREAKING**: Changed response
- **POST /antennas/create** **⚠️ BREAKING**: Changed body, response
- **POST /antennas/show** **⚠️ BREAKING**: Changed response
- **POST /antennas/update** **⚠️ BREAKING**: Changed body, response
- **POST /app/create** **⚠️ BREAKING**: Changed response
- **POST /app/show** **⚠️ BREAKING**: Changed response
- **POST /auth/session/show** **⚠️ BREAKING**: Changed response
- **POST /auth/session/userkey** **⚠️ BREAKING**: Changed response
- **POST /blocking/create** **⚠️ BREAKING**: Changed response
- **POST /blocking/delete** **⚠️ BREAKING**: Changed response
- **POST /blocking/list**: Changed body
- **POST /channels/create** **⚠️ BREAKING**: Changed response
- **POST /channels/followed**: Changed body
- **POST /channels/owned**: Changed body
- **POST /channels/search**: Changed body
- **POST /channels/show** **⚠️ BREAKING**: Changed response
- **POST /channels/timeline**: Changed body
- **POST /channels/update** **⚠️ BREAKING**: Changed response
- **GET /charts/federation** **⚠️ BREAKING**: Changed response
- **POST /charts/federation** **⚠️ BREAKING**: Changed response
- **POST /clips/create** **⚠️ BREAKING**: Changed response
- **POST /clips/list**: Changed body
- **POST /clips/notes**: Changed body
- **POST /clips/show** **⚠️ BREAKING**: Changed response
- **POST /clips/update** **⚠️ BREAKING**: Changed response
- **POST /drive/files**: Changed body
- **POST /drive/files/attached-notes**: Changed body
- **POST /drive/files/create** **⚠️ BREAKING**: Changed response
- **POST /drive/files/show** **⚠️ BREAKING**: Changed body, response
- **POST /drive/files/update** **⚠️ BREAKING**: Changed response
- **POST /drive/folders**: Changed body
- **POST /drive/folders/create** **⚠️ BREAKING**: Changed response
- **POST /drive/folders/show** **⚠️ BREAKING**: Changed response
- **POST /drive/folders/update** **⚠️ BREAKING**: Changed response
- **POST /drive/stream**: Changed body
- **GET /emoji** **⚠️ BREAKING**: Changed response
- **POST /emoji** **⚠️ BREAKING**: Changed response
- **POST /federation/followers**: Changed body
- **POST /federation/following**: Changed body
- **POST /federation/show-instance** **⚠️ BREAKING**: Changed response
- **POST /federation/users**: Changed body
- **POST /flash/create** **⚠️ BREAKING**: Changed response
- **POST /flash/my**: Changed body
- **POST /flash/my-likes**: Changed body
- **POST /flash/show** **⚠️ BREAKING**: Changed response
- **POST /following/create** **⚠️ BREAKING**: Changed response
- **POST /following/delete** **⚠️ BREAKING**: Changed response
- **POST /following/invalidate** **⚠️ BREAKING**: Changed response
- **POST /following/requests/cancel** **⚠️ BREAKING**: Changed response
- **POST /following/requests/list**: Changed body
- **POST /following/requests/sent**: Changed body
- **POST /following/update** **⚠️ BREAKING**: Changed response
- **POST /gallery/posts**: Changed body
- **POST /gallery/posts/create** **⚠️ BREAKING**: Changed response
- **POST /gallery/posts/show** **⚠️ BREAKING**: Changed response
- **POST /gallery/posts/update** **⚠️ BREAKING**: Changed response
- **POST /hashtags/show** **⚠️ BREAKING**: Changed response
- **POST /hashtags/users**: Changed body
- **POST /i** **⚠️ BREAKING**: Changed response
- **POST /i/claim-achievement**: Changed body
- **POST /i/favorites**: Changed body
- **POST /i/gallery/likes**: Changed body
- **POST /i/gallery/posts**: Changed body
- **POST /i/notifications**: Changed body
- **POST /i/notifications-grouped**: Changed body
- **POST /i/page-likes**: Changed body
- **POST /i/pages**: Changed body
- **POST /i/pin** **⚠️ BREAKING**: Changed response
- **POST /i/revoke-token**: Changed body
- **POST /i/signin-history**: Changed body
- **POST /i/unpin** **⚠️ BREAKING**: Changed response
- **POST /i/update** **⚠️ BREAKING**: Changed body, response
- **POST /i/update-email** **⚠️ BREAKING**: Changed response
- **POST /i/webhooks/show** **⚠️ BREAKING**: Changed response
- **POST /i/webhooks/test**: Changed body
- **POST /invite/create** **⚠️ BREAKING**: Changed response
- **POST /invite/list**: Changed body
- **POST /mute/list**: Changed body
- **POST /notes**: Changed body
- **POST /notes/children**: Changed body
- **POST /notes/create** **⚠️ BREAKING**: Changed body, response
- **POST /notes/global-timeline**: Changed body
- **POST /notes/hybrid-timeline**: Changed body
- **POST /notes/local-timeline**: Changed body
- **POST /notes/mentions**: Changed body
- **GET /notes/reactions**: Changed body
- **POST /notes/reactions**: Changed body
- **POST /notes/renotes**: Changed body
- **POST /notes/replies**: Changed body
- **POST /notes/search**: Changed body
- **POST /notes/search-by-tag**: Changed body
- **POST /notes/show** **⚠️ BREAKING**: Changed response
- **POST /notes/state** **⚠️ BREAKING**: Changed response
- **POST /notes/timeline**: Changed body
- **POST /notes/user-list-timeline**: Changed body
- **POST /notifications/create** **⚠️ BREAKING**: Changed response
- **POST /pages/create** **⚠️ BREAKING**: Changed body, response
- **POST /pages/show** **⚠️ BREAKING**: Changed body, response
- **POST /pages/update**: Changed body
- **POST /renote-mute/list**: Changed body
- **POST /reversi/games**: Changed body
- **POST /reversi/match** **⚠️ BREAKING**: Changed response
- **POST /reversi/show-game** **⚠️ BREAKING**: Changed response
- **POST /reversi/verify** **⚠️ BREAKING**: Changed response
- **POST /roles/notes**: Changed body
- **POST /roles/show** **⚠️ BREAKING**: Changed response
- **POST /roles/users**: Changed body
- **POST /users**: Changed body
- **POST /users/clips**: Changed body
- **POST /users/flashs**: Changed body
- **POST /users/followers**: Changed body
- **POST /users/following**: Changed body
- **POST /users/gallery/posts**: Changed body
- **POST /users/lists/create** **⚠️ BREAKING**: Changed response
- **POST /users/lists/create-from-public** **⚠️ BREAKING**: Changed response
- **POST /users/lists/get-memberships**: Changed body
- **POST /users/lists/update** **⚠️ BREAKING**: Changed response
- **POST /users/notes**: Changed body
- **POST /users/pages**: Changed body
- **POST /users/report-abuse**: Changed body
- **POST /users/search-by-username-and-host**: Changed body
- **POST /users/show**: Changed body
- **POST /v2/admin/emoji/list**: Changed body


### Added Schemas

- `UserGroup`
- `Achievement`
- `AchievementName`
- `NoteReactionWithNote`
- `QueueMetrics`
- `QueueJob`
- `UserWebhook`
- `NoteHistory`


### Removed Schemas

- `UserListMembership`
- `UserAccountMoveLog`
- `FollowRequest`
- `PageLike`
- `GalleryLike`
- `FlashLike`
- `AbuseUserReport`
- `ModerationLog`


### Modified Schemas

- `UserLite` **⚠️ BREAKING**
- `UserDetailedNotMeOnly` **⚠️ BREAKING**
- `MeDetailedOnly` **⚠️ BREAKING**
- `Ad` **⚠️ BREAKING**
- `Announcement` **⚠️ BREAKING**
- `Note` **⚠️ BREAKING**
- `NoteDraft` **⚠️ BREAKING**
- `NoteReaction` **⚠️ BREAKING**
- `NoteFavorite` **⚠️ BREAKING**
- `DriveFile` **⚠️ BREAKING**
- `DriveFolder` **⚠️ BREAKING**
- `Following` **⚠️ BREAKING**
- `Muting` **⚠️ BREAKING**
- `RenoteMuting` **⚠️ BREAKING**
- `Blocking` **⚠️ BREAKING**
- `InviteCode` **⚠️ BREAKING**
- `Page` **⚠️ BREAKING**
- `Antenna` **⚠️ BREAKING**
- `Clip` **⚠️ BREAKING**
- `FederationInstance` **⚠️ BREAKING**
- `GalleryPost` **⚠️ BREAKING**
- `EmojiSimple` **⚠️ BREAKING**
- `EmojiDetailed` **⚠️ BREAKING**
- `Flash` **⚠️ BREAKING**
- `RoleCondFormulaValueNot` **⚠️ BREAKING**
- `RolePolicies` **⚠️ BREAKING**
- `ReversiGameLite` **⚠️ BREAKING**
- `ReversiGameDetailed` **⚠️ BREAKING**
- `MetaLite` **⚠️ BREAKING**
- `MetaDetailedOnly` **⚠️ BREAKING**
- `AbuseReportNotificationRecipient` **⚠️ BREAKING**
- `ChatMessage` **⚠️ BREAKING**
- `ChatMessageLite` **⚠️ BREAKING**
- `ChatMessageLiteFor1on1` **⚠️ BREAKING**
- `ChatMessageLiteForRoom` **⚠️ BREAKING**
- `ChatRoom` **⚠️ BREAKING**
- `ChatRoomInvitation` **⚠️ BREAKING**
- `ChatRoomMembership` **⚠️ BREAKING**


---
*Generated on 2026-02-07T08:13:08.753Z*