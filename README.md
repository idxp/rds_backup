# RDS Backup

[![Code Climate](https://codeclimate.com/repos/541c35efe30ba0721e03ecd2/badges/b5fa8a7cfcaf16d58331/gpa.svg)](https://codeclimate.com/repos/541c35efe30ba0721e03ecd2/feed)

This gem backs up RDS databases to different cloud providers, granting an extra level of mind peacefulness.

## Installation

`rds_backup` should be run as a command line tool, so it makes sense to install it globally

```bash
$ gem install rds_backup
```

## Usage

`rds_backup` expects a `config.yml` file on the folder it is run, [here is a sample](config.yml.sample).

Currently, you need a Google Cloud account with access to Cloud Storage. Sign up [here](https://developers.google.com/storage/docs/signup?csw=1) and get your credentials [here](https://storage.cloud.google.com/m) under the section "Interoperable Access".

AWS credentials with access to SES and a Hipchat Room token from API v2 are also required at this time.

Then, simply run the gem's binary:

```bash
$ rds_backup
```

### Cron Usage

This tool is usually scheduled in cron, below is an example

```
0 3 * * * . $HOME/.profile; cd $HOME/rds_backup && rds_backup >> /var/log/rds_backup/rds_backup.log 2>&1
```

## Roadmap

* Tests
* Multiple cloud providers (we're already using fog)
* More yell adapters (Slack, Campfire, IRC, etc)
* More flexibe rules on backups to keep (à la [ec2-expire-snapshots](https://github.com/alestic/ec2-expire-snapshots))

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
