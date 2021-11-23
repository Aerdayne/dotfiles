# !/usr/local/bin/fish

function download_wallpaper
  set --local name (string split / $argv[1])
  set --local wallpaper_path ~/wallpapers/$name[-1]
  curl -o $wallpaper_path "$argv"
end

download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/041/840/127/4k/david-frasheski-snowy-peaks.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/043/276/380/4k/philipp-a-urlich-cpncept378-b.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/043/276/316/4k/philipp-a-urlich-cpncept373-c.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/043/276/521/4k/philipp-a-urlich-cpncept374-c.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/043/276/557/4k/philipp-a-urlich-cpncept376-2.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/043/276/264/4k/philipp-a-urlich-cpncept372-b.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/043/276/078/4k/philipp-a-urlich-cpncept365.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/043/275/968/4k/philipp-a-urlich-cpncept362-3.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/042/487/014/4k/philipp-a-urlich-cpncept360-b.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/042/486/914/4k/philipp-a-urlich-cpncept356b.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/041/401/301/4k/philipp-a-urlich-cpncept348.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/041/771/490/4k/philipp-a-urlich-cpncept354d-low.jpg'
