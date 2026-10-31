#!/bin/bash
# Rough-cut trailer from the browser build. Needs node + Playwright and ffmpeg.
# Usage: tools/trailer/cut.sh  (writes wickbearer-trailer.mp4 in a temp folder and prints its path)
set -e
here=$(cd "$(dirname "$0")" && pwd); work=$(mktemp -d); cd "$work"
cp "$here"/*.js "$here"/card.html .
sed 's/function aSpawn(st) {/function aSpawn(st) { window.__st = st;/' "$here/../../web/tenebrae-play.html" > game.html
node rec.js "$work/game.html" story 22 story v_story & node rec.js "$work/game.html" chapter=2 22 move v_move &
node rec.js "$work/game.html" chapter=4 20 skills v_skills & node rec.js "$work/game.html" final 30 boss v_boss & wait
node cards.js "$work/card.html"
V="scale=1152:720,pad=1280:720:64:0:black,fps=30,format=yuv420p,setsar=1"
seg(){ ffmpeg -loglevel error -y -ss $2 -t $3 -i "$(ls v_$1/*.webm)" -vf "$V,fade=t=in:st=0:d=0.3,fade=t=out:st=$(python3 -c "print($3-0.3)"):d=0.3" -an -c:v libx264 -preset fast -crf 18 $4.mp4; }
card(){ ffmpeg -loglevel error -y -loop 1 -t $2 -i $1.png -vf "fps=30,format=yuv420p,setsar=1,fade=t=in:st=0:d=0.4,fade=t=out:st=$(python3 -c "print($2-0.4)"):d=0.4" -c:v libx264 -preset fast -crf 18 $1.mp4; }
seg story 0.6 16 s1; card c1 2; seg move 2.5 10 s2; card c2 2; seg skills 5 12 s3; card c3 2.2; seg boss 6 16 s4; card c4 3.5; card c5 3
printf "file %s\n" s1.mp4 c1.mp4 s2.mp4 c2.mp4 s3.mp4 c3.mp4 s4.mp4 c4.mp4 c5.mp4 > list.txt
ffmpeg -loglevel error -y -f concat -safe 0 -i list.txt -c copy wickbearer-trailer.mp4
echo "$work/wickbearer-trailer.mp4"
