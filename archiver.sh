#!/bin/bash

# Disk
#drive="/dev/sdb"

# Webcam options
framerate="15"
tmppath="/tmp/disk.png"
webcamformat="mjpeg"

#videosizeopt="-video_size"
videosizeopt=
#ffplayvideosize="1920x1080"
ffplayvideosize=
ffmpegvideosize="1920x1080"
#pixelformatopt="-pixel_format"
pixelformatopt=
#pixelformat="yuyv422"
pixelformat=

# Folder to save the files in
archivepath="./archive"


# Automatic setup stuff
whiptail_height="$(($(tput lines) - 6))"
whiptail_width="$(($(tput cols) - 20))"
if [[ ! -e "$archivepath" ]]; then
	mkdir "$archivepath"
fi

getstate() {
	if [[ -e "$archivepath"/lastserial ]]; then
		diskserial="$(cat "$archivepath"/lastserial)"
	else
		diskserial=000000
	fi

	if [[ -e "$archivepath"/currentstack ]]; then
		stackserial="$(cat "$archivepath"/currentstack)"
	else
		stackserial=00
	fi

	if [[ -e "$archivepath"/lastnewstack ]]; then
		lastnewstack="$(cat "$archivepath"/lastnewstack)"
	else
		lastnewstack="${stackserial}"
	fi

	if [[ -e "$archivepath"/contentstype ]]; then
		contentstype="$(cat "$archivepath"/contentstype)"
	else
		contentstype="unkn"
	fi
}

savestate() {
	echo "$diskserial" > "$archivepath"/lastserial
	echo "$stackserial" > "$archivepath"/currentstack
	echo "$lastnewstack" > "$archivepath"/lastnewstack
	echo "$contentstype" > "$archivepath"/contentstype
}

webcamsetup() {
#	numwebcams="$(find /dev/video* | wc -l)"
#	for i in $(eval echo "{0..$((numwebcams - 1))}"); do
#		webcamoptions+=("/dev/video$i" ".")
#	done
	webcamoptions=()
	numwebcams=0
	for i in /dev/video*; do
		webcamoptions+=("$i" ".")
		numwebcams=$((numwebcams + 1))
	done

	webcamdev="$(whiptail --nocancel --title 'Webcam selection' --menu 'Webcam to take disk photos with' $whiptail_height $whiptail_width $((numwebcams + 1)) \
		"${webcamoptions[@]}" 3>&1 1>&2 2>&3)"
}

disksetup() {
#	lsblk -dpnro rm,name,size,type -x type | egrep '^1' | sed 's/^..//'
#	lsblk -dpnro rm,name,size,type -x type | egrep '^0' | sed 's/^..//'
	disks=()
	numdisks=0
	while IFS= read -r line; do
		disks+=("$(cut -d' ' -f 1 <<<"$line")" "$(cut -d' ' -f 2,3 <<<"$line" | sed 's/^/ /')")
		numdisks=$((numdisks+1))
	done <<<"$(lsblk -dpnro rm,name,size,type -x type | egrep '^1' | sort | sed 's/^..//')"
#	for i in "${testvar[@]}"; do echo "$i"; done

	drive="$(whiptail --nocancel --title 'Disk selection' --menu 'Floppy drive to use' $whiptail_height $whiptail_width $((numwebcams + 2)) \
		"${disks[@]}" 3>&1 1>&2 2>&3)"
}

getphoto() {
	# webcam -> splitter -> stdout -> ffplay -> preview screen
	#               \-> png file in /tmp, overwritten with every frame
#	ffmpeg -r "$framerate" -s "$videosize" -i "$webcamdev" -an -update 1 -y "$tmppath" -an -c:v copy -f rawvideo - 2>/dev/null | ffplay -f rawvideo -video_size "$videosize" -pixel_format "$pixelformat" - 2>/dev/null
	ffmpeg -r "$framerate" -s "$ffmpegvideosize" -i "$webcamdev" -an -update 1 -y "$tmppath" -an -c:v copy -f rawvideo - 2>/dev/null | ffplay -f "$webcamformat" $videosizeop $ffplayvideosize $pixelformatopt $pixelformat -
	cp "$tmppath" "$archivepath/$filename.png"
}

getdiskname() {
	filename="$diskserial"

	# Ask for stack, current as default.
	laststackserial="$stackserial"
	laststackserial="$(echo "$laststackserial" | sed 's/^0*\(.*\)$/\1/')" # remove starting 0s to prevent $(( ... )) from thinking decimal is octal
	lastnewstack="$(echo "$lastnewstack" | sed 's/^0*\(.*\)$/\1/')" # remove starting 0s to prevent $(( ... )) from thinking decimal is octal
	stackserial="$(whiptail --nocancel --title 'Stack Number' --menu 'Serial number of the current stack/group of disks' $whiptail_height $whiptail_width 5 \
		"$stackserial"				'Current number' \
		"$((lastnewstack + 1))"		'Next available stack' \
		'0'							'Individual/no stack' \
		'c'							'Custom' 3>&1 1>&2 2>&3)"
	if [[ "$stackserial" == 'c' ]]; then
		stackserial="$(whiptail --nocancel --title 'Stack Number' --inputbox 'Serial number of the current stack/group of disks' $whiptail_height $whiptail_width "$laststackserial" 3>&1 1>&2 2>&3 \
			| sed 's/[^0-9]//g')"
	fi
	stackserial="$(echo "$stackserial" | sed 's/^0*\(.*\)$/\1/')" # remove starting 0s to prevent things from thinking decimal is octal
	if [[ "$stackserial" -gt "$((lastnewstack + 1))" ]]; then
		echo "Stack number greater than next available stack. Clamping to that."
		stackserial="$((lastnewstack + 1))"
	fi
	if [[ "$stackserial" -eq "$((lastnewstack + 1))" ]]; then
		lastnewstack="$stackserial"
	fi
	stackserial="$(echo "$stackserial" | sed 's/^0*\(.*\)$/\1/')" # remove starting 0s to prevent printf from thinking decimal is octal
	stackserial="$(printf "%02d" "$stackserial")"
	filename="${filename}-${stackserial}"

	# Ask for interest level, 0 as default
	interestlevel="$(whiptail --nocancel --title 'Interest level' --menu 'How interesting is this disk?' $whiptail_height $whiptail_width 7 \
		'0' 'meh' \
		'1' 'look at it later I guess' \
		'2' 'could be interesting' \
		'3' 'interesting' \
		'4' 'cool' \
		'5' 'archive.org this shit' 3>&1 1>&2 2>&3)"
	filename="${filename}-${interestlevel}"

	# Ask for density
	density="$(whiptail --nocancel --title 'Disk density' --menu 'This could be autodetected, but whatever' $whiptail_height $whiptail_width 4 \
		'1.44m' 'HD MFM 3.25"' \
		'720kb' 'DD MFM 3.25"' \
		'120mb' 'LS-120 Super Disk' 3>&1 1>&2 2>&3)"
	filename="${filename}-${density}"

	# Ask for the type of disk contents
	lastcontentstype="$contentstype"
	contentstype="$(whiptail --nocancel --title 'Disk contents' --menu 'Categorize the disk contents based on the label' $whiptail_height $whiptail_width 6 \
		"$lastcontentstype" '(Last type)' \
		'data' 'Disk with user data or generally a handwritten label' \
		'swof' 'Official software; printed label' \
		'swcp' 'Copied software; handwritten label that indicates software' \
		'unkn' 'Unknown; implies handwritten label' 3>&1 1>&2 2>&3)"
	filename="${filename}-${contentstype}"

	# Ask for description
	description="$(whiptail --nocancel --title 'Description (Optional)' --inputbox 'Completely optional description field. [a-zA-Z0-9\.,_]' $whiptail_height $whiptail_width '' 3>&1 1>&2 2>&3 \
		| sed 's/[ -]/_/g;s/[^a-zA-Z0-9\.,_]//g')"
	filename="${filename}-${description}"

}

readdisk() {
	whiptail --nocancel --title 'Insert disk' --msgbox 'Insert the disk, then continue' $whiptail_height $whiptail_width 3>&1 1>&2 2>&3
	if sudo ddrescue -d -n -r3 "$drive" "${archivepath}/${filename}.img" "${archivepath}/${filename}.map"; then
		whiptail --nocancel --title 'Success' --msgbox '' $whiptail_height $whiptail_width 3>&1 1>&2 2>&3
	else
		whiptail --nocancel --title 'Failed to ddrescue disk' --msgbox '' $whiptail_height $whiptail_width 3>&1 1>&2 2>&3
	fi
	sudo eject "$drive"
}

# Archives a disk
archivedisks() {
	getstate
	while true; do
		diskserial="$(echo "$diskserial" | sed 's/^0*\(.*\)$/\1/')" # remove starting 0s to prevent $(( ... )) from thinking decimal is octal
		diskserial="$(($diskserial + 1))" # increment
		diskserial="$(printf "%06d" "$diskserial")" # Print as 6 digits zero padded

		# get disk filename
		getdiskname

		# confirm filename
		if whiptail --nocancel --title 'Confirm name' --yesno "Do you want to continue with \"${filename}\"?" $whiptail_height $whiptail_width 3>&1 1>&2 2>&3; then
			true # do nothing
		else
			continue
		fi

		# Save current state in case ddrescue needs to be killed or something
		savestate



		# Take photo of disk
		getphoto

		#do disk imaging,
		#if ddrescue had trouble, save the map too, otherwise discard it.
		readdisk

		# Ask if you have more disks
		if whiptail --nocancel --title 'Archive another?' --yesno 'Do you want to archive another disk?' $whiptail_height $whiptail_width 3>&1 1>&2 2>&3; then
			true # do nothing
			# could be `:`?
		else
			break
		fi
		getstate
	done
}

remapstacks() {
	# remap stacks (16 to 10) (needs archive path added):
	# for i in *-16-*; do mv "$i" $(echo "$i" | sed 's/-16-/-10-/'); done
	echo "not implemented"
}

inspectdisk() {
	echo "not implemented"
}

mainmenu() {
	while true; do
		case $(whiptail --nocancel --title 'Main menu' --menu 'What do you want to do?' $whiptail_height $whiptail_width 7 \
			'1' 'Archive disks' \
			'2' "Change drive ($drive)" \
			'3' "Chane webcam ($webcamdev)" \
			'4' 'Remap stacks (be careful)' \
			'5' 'Inspect disk' \
			'6' 'exit' 3>&1 1>&2 2>&3) in

			1) archivedisks;;
			2) disksetup;;
			3) webcamsetup;;
			4) remapstacks;;
			5) inspectdisk;;
			6) break;;
		esac
	done
}

webcamsetup
disksetup
echo "Using webcam: $webcamdev"

mainmenu
