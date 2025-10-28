function 2mkv
	HandBrakeCLI \
		--input $argv[1] \
		--output $argv[2] \
		--main-feature --markers --optimize --ipod-atom \
		--encoder-tune film \
		--encoder x264 --encoder-profile high --encoder-preset medium --encoder-level 4.1 --quality 20 \
		--maxWidth 1920 \
		--maxHeight 1080 \
		--decomb --auto-anamorphic --cfr \
		--all-audio \
		--aencoder copy --audio-fallback av_aac --ab 160 \
		--all-subtitles
end

# should test this with quality 18 and check filesize
function 2mkv265
	HandBrakeCLI \
		--input $argv[1] \
		--output $argv[2] \
		--encoder x265 \
		--encoder-preset medium \
		--quality 18 \
		--decomb --auto-anamorphic --cfr \
		--all-audio \
		--aencoder copy --audio-fallback av_aac --ab 160 \
		--all-subtitles
end
