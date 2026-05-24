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

> "Bash-ing out an email."

<img src="https://github.com/user-attachments/assets/df5d82ad-261c-4ca9-b085-ed593fca77e0" alt="VinMail - Preview" align="right" height="250px">VinMail is an interactive CLI mail manager written in Bash. It sits on top of msmtp and gives you a proper terminal interface for managing multiple email accounts and sending mail, without needing any graphical client or external dependencies beyond what you likely already have.

At its core, VinMail handles everything itself. It builds the full RFC 2822 MIME message in Bash, including headers, body, and attachments, then pipes it directly to msmtp for delivery. No mail daemon, no sendmail, no intermediate client.

Account management is built around a simple registry of aliases. Add an account once through the guided wizard, and from then on switching between accounts is just navigating a menu and pressing Enter. The active account config is copied to `~/.msmtprc` so msmtp always knows which account to use. App passwords can be stored as plain text with strict file permissions, or encrypted with a GPG key so the password never sits on disk in readable form.

Composing a mail opens a persistent screen where every field (To, Cc, Bcc, Subject, body, and attachments) remains editable until you confirm sending. The body opens in your `$EDITOR` of choice. Attachments are base64-encoded and sent as proper MIME multipart messages. Messages can also be GPG-signed, with the body kept as plain readable text and the clearsigned version attached separately as `signature.asc` for recipients who want to verify it.

Navigation throughout uses arrow keys and j/k, so it feels natural if you spend time in vim or any other terminal tool.

### More: \[[Installation](https://github.com/VintellX/vinmail/wiki/Installation)\] \[[User Guide](https://github.com/VintellX/vinmail/wiki/User-Guide)\] 
