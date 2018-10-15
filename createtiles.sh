#!/bin/bash

filename=$1 
# Obtain Name of the file
name="$(cut -d '.' -f1 <<<"$filename")"

# Parameters
#------------------------
square=256
bckcolor="grey"
zoomlevel=7
annotate="Testing"
#------------------------


outputname=$(echo $filename | sha1sum )
outputname=${outputname::-2}
outputname=$(echo -n $outputname)

format=".png"
outputname+=$format

output=$outputname

# Create SVG
convert -density $2 -background $bckcolor $filename $output 

# Get Dimension of SVG
res="$(identify $output  | cut -d' ' -f3)"
xdim="$(cut -d 'x' -f1 <<<"$res")"
ydim="$(cut -d 'x' -f2 <<<"$res")"

xi=$(bc -l <<< $xdim/$square)
yi=$(bc -l <<< $ydim/$square)

xi=$(bc <<< "($xi+0.5)/1")
yi=$(bc <<< "($yi+0.5)/1")

xfactor=$(bc -l <<<"l($xi)/l(2)")
yfactor=$(bc -l <<<"l($yi)/l(2)")

xfactortmp=$xfactor
yfactortmp=$yfactor
xfactortmp=$(cut -d '.' -f1 <<<"$xfactortmp")
yfactortmp=$(cut -d '.' -f1 <<<"$yfactortmp")

# Now eliminate rounding
xfactor=$(bc <<< "($xfactor+0.5)/1")
yfactor=$(bc <<< "($yfactor+0.5)/1")

if [ "$xfactortmp" -ge "$yfactortmp" ]; then
	# Rescale with respect to width
	argument="-resize "$(bc <<< $square*2^$xfactor)
else
	# Resacle with repsect to height
	argument="-resize x"$(bc <<< $square*2^$yfactor)
fi

# Reduce to desired 
convert $output $argument $output

# Rescaling changes the dimensions
res="$(identify $output  | cut -d' ' -f3)"
xdim="$(cut -d 'x' -f1 <<<"$res")"
ydim="$(cut -d 'x' -f2 <<<"$res")"

# Whats missing for square*2^factor ?

xtoaddleft=$(bc -l<<< "(($square*2^$xfactor-$xdim))/2")
ytoaddleft=$(bc -l<<< "(($square*2^$yfactor-$ydim))/2")


xtoaddleft=$(cut -d '.' -f1 <<<"$xtoaddleft")
ytoaddleft=$(cut -d '.' -f1 <<<"$ytoaddleft")


if [ "$xtoaddleft" -lt 0 ]; then
	xtoaddleft=$(bc -l<<< "((2*$square*2^$xfactor-$xdim))/2")
	xfactor=$(bc -l<<< "$xfactor+1")
fi

if [ "$ytoaddleft" -lt 0 ]; then
	ytoaddleft=$(bc -l<<< "((2*$square*2^$yfactor-$ydim))/2")
	yfactor=$(bc -l<<< "$yfactor+1")
fi

xtoaddleft=$(cut -d '.' -f1 <<<"$xtoaddleft")
ytoaddleft=$(cut -d '.' -f1 <<<"$ytoaddleft")

if [ "$xtoaddleft" -gt 0 ]; then
	xtoaddright=$(bc -l <<< "sqrt(($square*2^$xfactor-$xdim)^2)-$xtoaddleft")
else
	xtoaddright=0
fi

if [ "$ytoaddleft" -gt 0 ]; then
	ytoaddright=$(bc -l <<< "sqrt(($square*2^$yfactor-$ydim)^2)-$ytoaddleft")
else
	ytoaddright=0
fi

xtoaddright=$(cut -d '.' -f1 <<<"$xtoaddright")
ytoaddright=$(cut -d '.' -f1 <<<"$ytoaddright")

convert -background $bckcolor -splice $xtoaddleft"x"$ytoaddleft $output -gravity southeast -background $bckcolor -splice $xtoaddright"x"$ytoaddright $output

res="$(identify $output  | cut -d' ' -f3)"
xdim="$(cut -d 'x' -f1 <<<"$res")"
ydim="$(cut -d 'x' -f2 <<<"$res")"

int=$xfactor

if [ "$xfactor" -gt "$yfactor" ]; then
    int=$yfactor
fi


#Determine max zoomlevel
if [ "$zoomlevel" -gt "$int" ]; then
    zoomlevel=$int
fi

echo "Zoomlevel: " $zoomlevel
echo "Dim: " $xdim " x " $ydim

rm -r $name
mkdir $name

for i in $( eval echo {0..$zoomlevel} )
do
	# Create dir for zoomlevel
	tmpdir=$name"/"$(bc  <<< $zoomlevel-$i)
	mkdir $tmpdir

	division=$(bc  <<< 2^$i )

	xresize=$(bc  <<< $xdim/$division )
	yresize=$(bc  <<< $ydim/$division )
	
	tmppath=$tmpdir"/tmp.png"
	# Create the zoomed image

	echo "Working on:" $xresize " x " $yresize

	convert -resize $xresize"x"$yresize $output $tmppath

	# How many in a row
	nrofcols=$(bc  <<< $xresize/$square )

	# Slice the image
	convert $tmppath -crop $square"x"$square +repage $tmpdir"/map_%d.png"
 
	rm $tmppath

	# Rename the files
	for entry in $(eval echo $tmpdir"/*.png")
	do
		regex="\/map_(.*)\.png"
		[[ $entry =~ $regex ]]
		nr=${BASH_REMATCH[1]}

		rowindex=$(bc  <<< $nr/$nrofcols )
		colindex=$(bc  <<< $nr%$nrofcols)

		# Annotate the tiles	
		convert -fill white -annotate 0 $annotate -gravity Center  $entry $tmpdir"/map_"$rowindex"_"$colindex".png"
			
		rm $entry
	done
done

echo "Finished"




