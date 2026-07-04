<h3 align="center">
<pre>
 __     ___       __  __       _ _
 \ \   / (_)_ __ |  \/  | __ _(_) |
  \ \ / /| | '_ \| |\/| |/ _` | | |
   \ V / | | | | | |  | | (_| | | |
    \_/  |_|_| |_|_|  |_|\__,_|_|_|
</pre>
</h3>

<p align="center">Interactive Bash-based mail client for msmtp with multi-account management and GPG support.</p>

<p align="center">
<a href="./LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
<a href="https://github.com/VintellX/vinmail/releases"><img src="https://img.shields.io/github/release/VintellX/vinmail.svg"></a>
<img src="https://img.shields.io/github/release-date/VintellX/vinmail?display_date=published_at">
</p>

<h3 align="center">
  Quick Links:
  [<a href="https://github.com/VintellX/vinmail/wiki/Installation">Installation</a>]
  [<a href="https://github.com/VintellX/vinmail/wiki/User-Guide">User Guide</a>]
  [<a href="https://github.com/VintellX/vinmail/releases">Releases</a>]
</h3>

> "Bash-ing out an email."

<img src="https://github.com/user-attachments/assets/50d823c8-8580-4850-803f-6808539197d6" alt="VinMail - Preview" align="right" height="250px">VinMail is an interactive CLI mail manager written in Bash. It sits on top of msmtp and gives you a proper terminal interface for managing multiple email accounts and sending mail, without needing any graphical client or external dependencies beyond what you likely already have.

At its core, VinMail handles everything itself. It builds the full RFC 2822 MIME message in Bash, including headers, body, and attachments, then pipes it directly to msmtp for delivery. No mail daemon, no sendmail, no intermediate client.

Account management is built around a simple registry of aliases. Add an account once through the guided wizard, and from then on switching between accounts is just navigating a menu and pressing Enter. The active account config is copied to `~/.msmtprc` so msmtp always knows which account to use. App passwords can be stored as plain text with strict file permissions, or encrypted with a GPG key so the password never sits on disk in readable form.

Composing a mail opens a persistent screen where every field (To, Cc, Bcc, Subject, body, and attachments) remains editable until you confirm sending. The body opens in your `$EDITOR` of choice (vim or emacs: which one would you smash? TvT). Attachments are base64-encoded and sent as proper MIME multipart messages. Messages can also be GPG-signed, with the body kept as plain readable text and the clearsigned version attached separately as `signature.asc` for recipients who want to verify it.

VinMail also supports replying to received mail. Provide the original message as a `.eml` file and VinMail parses the sender, subject, and threading headers automatically, quotes the original body, and opens the compose screen pre-filled. Reply-to-sender and reply-all are both supported, with your own address filtered out of the recipient list. Drafts can be saved at any point during composition and resumed later from the main menu.

Navigation throughout uses arrow keys and j/k, so it feels natural if you spend time in vim or any other terminal tool.

<!-- ### More: \[[Installation](https://github.com/VintellX/vinmail/wiki/Installation)\] \[[User Guide](https://github.com/VintellX/vinmail/wiki/User-Guide)\]  -->
