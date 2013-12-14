Bundle up!
==========

A simple differential backup utility based on git bundles.

This utility creates git bundles that are timestamped and that contain history hash refs. To unbundle one would simply download all the bundles and run the following in a new repository:

`find .. -name '*.bundle' | sort | xargs -n1 -I'{}' git pull {} master`

This will reassemble all the bundles into the repository. Manual assembly may be required if one of the bundles is lost, so please be careful with storage.

The script will try to source a backup.conf file from the current pwd. This can be overriden by supplying the `BACKUP_CONFIG_PATH` variable.

Setting the `BACKUP_REPOSITORY_PATH` is also possible. By default this is the .backup directory of the current pwd.

There are several functions that you need to override:

- `post_create_repository` - called when a repository is initialized for the first time. You can set git configurations, optimizations, ignores, large file handling rules, etc.
- `cleanup` - called when the repository needs to be reset to an empty state. By default calls rm -rf. Override if needed.
- `do_backup` - called when files need to be copied over. Do anything you want at this point.	
- `process_bundle` - is called with the bundle name as its one and only agrument. Use this to upload the bundle to anywhere you want it to be.
