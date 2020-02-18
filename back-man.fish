#!/usr/bin/env fish


set default_config_file '__back_man.conf.def'

set config_dir "$HOME/.config"
begin
	# set config dir:
	if set --query XDG_CONFIG
		set config_dir "$XDG_CONFIG"
	end
	set config_dir "$config_dir/back-man"
end

set commands 'ls' 'add-cfg' 'run'

set options_with_descr \
	'h/help/print help'

function print_help
	echo "usage: "(status -f)" CMD [CONFIG] [OPTIONS...]"
	echo "CMD:"
	for cmd in $commands
		echo " $cmd"
	end
	echo "OPTIONS:"
	print_options_descr $options_with_descr
end

set options (options_descr_to_argparse $options_with_descr)

argparse --stop-nonopt \
	$options \
	-- \
	$argv
or begin
	print_help
	exit 1
end
if set --query _flag_help
	print_help
	exit
end
if test (count $argv) -lt 1
	echo "CMD expected!"
	print_help
	exit 1
end

function cmd_ls
	set options_with_descr \
		'h/help/print help'
	function print_help
		echo "usage: "
		echo "  "(status -f)" list [-h|--help]"
		echo "OPTIONS:"
		print_options_descr $options_with_descr
	end
	set -l options (options_descr_to_argparse $options_with_descr)
	argparse --max-args 0 \
		$options \
		-- \
		$argv
	or begin
		print_help
		exit 1
	end
	set --query _flag_help
	and begin
		print_help
		exit
	end
	for config in (find "$config_dir" -maxdepth 1 -type f)
		echo (basename (string match -re '(.*).conf' "$config")[2])
	end
end

function cmd_add_cfg
	set options_with_descr \
		'h/help/print help' \
		'f/force/owerwrite if already existing'
	function print_help
		echo "usage: "
		echo "  "(status -f)" add-cfg [-h|--help]"
		echo "  "(status -f)" add-cfg CONFIG [OPTIONS...] [SRC] [DST]"
		echo "OPTIONS:"
		print_options_descr $options_with_descr
	end
	set -l options (options_descr_to_argparse $options_with_descr)
	argparse \
		$options \
		-- \
		$argv
	or begin
		print_help
		exit 1
	end
	set --query _flag_help
	and begin
		print_help
		exit
	end
	begin
		set config_file "$config_dir/$argv[1].conf"
		set argv $argv[2..-1]
		set src "."
		if test "$argv[1]" != ""
			set src "$argv[1]"
		end
		set dst "."
		if test "$argv[2]" != ""
			set dst "$argv[2]"
		end
		set argv $argv[3..-1]
	end

	if begin
			test -f "$config_file"
			and not set --query _flag_force
	end
		echo "config file already exists '$config_file'" >&2
		exit 1
	end

	mkdir --parents (dirname "$config_file")
	touch "$config_file"

	# echo "config_file: '$config_file'"
	for line in (cat $default_config_file)
		echo (eval "echo $line") >> "$config_file"
	end
	echo "created '$config_file'"
end

function cmd_run
	set copy_opts_descr \
		'p/print-opts/print all options' \
		's/simulate/do not copy files (adds \'--dry-run\' to rsync options)' \
		'x/exclude=+/exclude these directories/files from copying' \
		"d/config-dir=/directory where to save ssh connections. Default: '\$HOME/$config_dir'" \
		"l/log-dir=/where to store log files. Default: '\$CONFIG_DIR/log'" \
		"r/rsync-option=+/set rsync options"
	set copy_cmd "backup"
	set options_with_descr \
		'h/help/print help' \
		'u/user=/run as user' \
		"c/cmd=/the command to run. One of copy|backup. default: $copy_cmd" \
		$copy_opts_descr
	set -g config_args \
		'user' \
		'cmd' \
		'src' \
		'dst'
	set -g config_opts
	for f in $copy_opts_descr
		set field_name (string match --regex './(.*)=' $f)[2]
		and begin
			set field_name (string replace '-' '_' $field_name)
			set --append config_opts $field_name
		end
	end
	function print_help
		echo "usage: "
		echo "  "(status -f)" run [-h|--help]"
		echo "  "(status -f)" run CONFIG [OPTIONS...] [SRC] [DST]"
		echo "DESCRIPTION:"
		echo "  Call '$copy_cmd' with arguments read from CONFIG."
		echo "  OPTIONS overwrite CONFIG"
		echo "OPTIONS:"
		print_options_descr $copy_opts_descr $options_with_descr
		echo "CONFIG entries:"
		for f in $config_args $config_opts "flags"
			echo "  $f"
		end
	end
	set -l options (options_descr_to_argparse $options_with_descr)

	argparse \
		$options \
		-- \
		$argv
	or begin
		print_help
		exit 1
	end
	set --query _flag_help
	and begin
		print_help
		exit
	end
	if test (count $argv) -lt 1 -o (count $argv) -gt 3
		print_help
		exit 1
	end

	set config_file "$config_dir/$argv[1].conf"
	if test ! -f "$config_file"
		echo "no config for '$argv[1]'" >&2
		exit 1
	end
	set argv $argv[2..-1]

	echo "config_file: '$config_file'"

	argparse --stop-nonopt \
		$options \
		-- \
		$argv
	or begin
		print_help
		exit 1
	end

	set copy_opts

	# validate config:
	for key in (yq -re 'keys[]' "$config_file" | grep --invert-match 'flags')
		if not contains "$key" $config_args $config_opts
			echo "ERROR: unknown config file entry '$key'"
			exit 1
		end
	end

	# set src, dst, user
	set src (yq -re '.src' "$config_file")
	set dst (yq -re '.dst' "$config_file")
	set user (yq -re '.user' "$config_file") >/dev/null; or set --erase user
	if yq -re '.cmd' "$config_file" > /dev/null
		set copy_cmd (yq -re '.cmd' "$config_file")
	end
	if test "$argv[1]" != ""
		set src "$argv[1]"
		set argv $argv[2..-1]
	end
	if test "$argv[1]" != ""
		set dst "$argv[1]"
		set argv $argv[2..-1]
	end
	set --query _flag_user; and set user "$_flag_user"
	set --query _flag_cmd; and set copy_cmd "$_flag_cmd"
	if test "$copy_cmd" = "copy"
		set copy_cmd "ct-copy.fish"
	else if test "$copy_cmd" = "backup"
		set copy_cmd "ct-backup.fish"
	else
		echo "CMD must be one of copy|backup"
		exit 1
	end

	# set copy_opts from config or flags
	for k in $copy_opts_descr
		# handle accumulative option:
		set key (string match --regex './(.*)=\+' $k)[2]
		and begin
			set -l flag_name (string join '' '_flag_' "$key")
			set -l flag_name (string replace -- '-' '_' (string join -- '' '_flag_' "$key"))
			set -l config_key (string replace '-' '_' "$key")
			if contains "$config_key" (yq -re 'keys[]' "$config_file")
				if test (yq -re ".$config_key|type" "$config_file") = "string"
					set value (yq -re ".$config_key"'' "$config_file")
				else if test (yq -re ".$config_key|type" "$config_file") = "array"
					set value (yq -re ".$config_key"'[]' "$config_file")
				else
					echo "config entry '$config_key' must be one of string|array"
					exit 1
				end
				for v in $value
					set --append copy_opts "$key=$v"
				end
			end
			if set --query "$flag_name"
				for v in $$flag_name
					set --append copy_opts "$key=$v"
				end
			end
		end
		# HANDLE NON-ACCumulative option:
		set key (string match --regex './(.*)=[^+]' $k)[2]
		and begin
			set -l flag_name (string replace -- '-' '_' (string join -- '' '_flag_' "$key"))
			set -l config_key (string replace -- '-' '_' "$key")
			# set from flag:
			if set --query "$flag_name"
				# echo "...set from flag: $flag_name"
				for v in $$flag_name
					set --append copy_opts "$key=$v"
				end
			# set from config:
			else if contains "$config_key" (yq -re 'keys[]' "$config_file")
				# echo ".. set from config"
				if test (yq -re ".$config_key|type" "$config_file") = "string"
					# echo "$key is a string"
					set value (yq -re ".$config_key"'' "$config_file")
				else if test (yq -re ".$config_key|type" "$config_file") = "array"
					# echo "$key is an array"
					set value (yq -re ".$config_key"'[]' "$config_file")
				else
					echo "config entry '$config_key' must be one of string|array"
					exit 1
				end
				for v in $value
					set --append copy_opts "$key=$v"
				end
			end
		end
	end

	set cmd_flags
	for opt in $copy_opts_descr
		set field_name (string match --regex '^./([^=]*)/' $opt)[2]
		and begin
			# set from flag:
			set -l flag_name (string join '' '_flag_' "$field_name")
			if set --query $flag_name
				set --append cmd_flags "--$field_name"
				# echo "non config opt: $field_name"
			end
		end
	end
	# load flags from config
	for key in (yq -re '.flags[]' "$config_file")
		if not contains -- "$key" $cmd_flags
			set --append cmd_flags "$key"
		end
	end

	set cmd
	if set --query user
		set --append cmd sudo -u "$user"
	end
	set --append cmd $copy_cmd
	for opt in $copy_opts
		# echo "option: $flag"
		set --append cmd "--$opt"
	end
	set --append cmd $cmd_flags
	for flag in $copy_opts
		set key_and_val (string split '=' $flag)
	end
	set --append cmd "$src" "$dst"

	echo "running: '$cmd'"
	$cmd
end

switch $argv[1]
	case 'ls'
		cmd_ls $argv[2..-1]
	case 'run'
		if test "$argv[2]" = ""
			echo "missing arg: CONFIG"
			print_help
			exit 1
		end
		cmd_run $argv[2..-1]
	case 'add-cfg'
		if test "$argv[2]" = ""
			echo "missing arg: CONFIG"
			print_help
			exit 1
		end
		cmd_add_cfg $argv[2..-1]
	case '*'
		echo "unknown CMD"
		print_help
end
