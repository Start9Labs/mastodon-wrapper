# Using Mastodon

## Key Information

When you run Mastodon on the Embassy, you are running your *own* Mastodon instance (aka node), rather than using someone else's and trusting them. Mastodon is a *federated* network - meaning multiple users can use a single instance, and instances can connect to each other, thus forming a truly decentralized and censorship-resistant network.

## Creating your Mastodon Account

When you first visit your Mastodon address, you will be asked to create the first account. Note, *you are creating an account with yourself*; There are no third parties involved. By default, your Mastodon instance is configured to allow only a single account - meaning, once you create your account, no one else will be permitted to create an account on your instance.

## Enabling Signups

To encourage self-hosting and to spare your Embassy the potential performance impact, multiple accounts are disabled by default. To override this default and permit others to create accounts on your instance, you can enable multiple accounts inside Config.

If you enable multiple accounts, it is recommended that you make them "invite only" and limit the number of account to less than 5. You can enable invite only mode inside the Server Administration menu of your primary Mastodon account.

## Configuring Email

Mastodon is capable of sending email notifications for invitations, or to alert you of mentions, comments, etc. This is an optional feature that is disabled by default. Because you are running your own Mastodon instance, if you want to receive email notifications, you will have to send them yourself. This can be done from your own SMTP server, or by using your account with a hosted SMTP server, such as Gmail, Outlook, Amazon SES, etc. For specific instructions on how to send an email using one of these services, try Googling "Gmail send with SMTP".

## Following

To follow someone on the federated network, simply visit their profile on any Mastodon instance and click the "Follow" button. Make sure you are logged in to your mastodon before doing so or you may get an error.

## Forgot Password

If you forget your Mastodon user password, there are two ways to reset it:
  1. If you have SMTP configured, you can use the standard "Forgot Password" flow through your Mastodon web site.
  2. In your Embassy Mastodon service, click Actions --> Reset Password.

## Restoring from Backup

**IMPORTANT** There is a known bug when restoring from backup that creates an incorrect .onion address.  To fix this, after a restore, you can downgrade Mastodon and then re-upgrade, and the issue will resolve itself.  A fix is in development for this.
