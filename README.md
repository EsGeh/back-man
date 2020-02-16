# backup-manager

Experimental command line utility for managing backup tasks based on config files.
This script is implemented as a wrapper around the `ct-backup.fish` command from [copy-tools](https://github.com/EsGeh/copy-tools) and has a very similar command line interface.

Work in progress. Use at your own risk.
Feedback welcome.

## Features

See ct-backup.fish in [copy-tools](https://github.com/EsGeh/copy-tools).

## Supported Operation Systems

So far only tested on Arch Linux.
(Might as well work on other systems if the necessary utilities are installed)

## Dependencies

- [copy-tools](https://github.com/EsGeh/copy-tools) (including its dependencies.

## Installation

You are on your own.

## Usage Example

1. list existing configs:

		$ backup.fish ls
		> some_config
		> some_other_config
		> ...

1. create a config:

		$ backup.fish add-cfg home /home/me user@remote:/backups/home
		> created '~/.config/backup-tools/home.conf'

		# edit command line arguments for ct-backup.fish:
		$ vi '~/.config/backup-tools/home.conf'

1. execute backup:

		# fist simulate:
		$ backup.fish run home --simulate

		# if all is ok, execute it:
		$ backup.fish run home

## Command line interface

Run

	$ backup.fish --help
