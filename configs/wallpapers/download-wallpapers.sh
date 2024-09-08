# !/usr/local/bin/fish

function download_wallpaper
  set --local name (string split / $argv[1])
  set --local wallpaper_path ~/wallpapers/$name[-1]
  curl -o $wallpaper_path "$argv"
end

mkdir ~/wallpapers

download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/041/840/127/4k/david-frasheski-snowy-peaks.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/025/591/810/4k/david-frasheski-cat-is-yelling-at-me-fin.jpg'

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
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/041/647/697/4k/philipp-a-urlich-cpncept351-3.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/041/535/305/4k/philipp-a-urlich-cpncept352-b.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/040/869/331/4k/philipp-a-urlich-cpncept342-3.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/039/066/703/4k/philipp-a-urlich-cpncept333d-2.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/038/856/084/4k/philipp-a-urlich-cpncept331b-3.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/038/458/449/4k/philipp-a-urlich-cpncept323b.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/039/609/676/4k/philipp-a-urlich-cpncept317-9.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/037/933/629/4k/philipp-a-urlich-trees-5c.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/037/897/073/4k/philipp-a-urlich-land1-9c.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/037/368/156/4k/philipp-a-urlich-mountain-view8b.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/037/269/792/4k/philipp-a-urlich-mountain-top-color7.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/036/605/305/4k/philipp-a-urlich-oldhouse3-4b.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/036/076/173/4k/philipp-a-urlich-lake2b.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/035/469/244/4k/philipp-a-urlich-desert-b.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/035/436/864/4k/philipp-a-urlich-cpncept307-3b.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/034/155/104/4k/philipp-a-urlich-cpncept293.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/043/973/119/large/philipp-a-urlich-cpncept381-d.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/048/292/255/4k/philipp-a-urlich-cpncept408c.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/046/314/444/4k/philipp-a-urlich-cpncept398-b.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/055/329/465/4k/philipp-a-urlich-cpncept469-2-small.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/061/316/153/4k/philipp-a-urlich-cpncept524c.jpg'

download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/019/921/209/4k/laszlo-szabados-000.jpg'

download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/018/782/568/4k/connor-sheehan-ironforge-redux.jpg'

download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/026/481/586/large/alena-aenami-wait.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/014/905/850/large/alena-aenami-witcher-1k.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/006/927/312/large/alena-aenami-quiet-1px.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/008/084/830/large/alena-aenami-solar-1k.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/004/446/155/large/alena-aenami-serenity-1k.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/003/316/239/large/alena-aenami-castle2k.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/002/844/038/large/alena-aenami-reflect1k.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/002/715/085/large/alena-aenami-sky1k.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/002/245/239/large/alena-aenami-redskyf1920.jpg'
download_wallpaper 'https://cdnb.artstation.com/p/assets/images/images/002/222/165/large/alena-aenami-mountains.jpg'
download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/002/446/988/large/alena-aenami-mountains1k.jpg'

download_wallpaper 'https://cdna.artstation.com/p/assets/images/images/045/566/294/4k/alisher-mirzoev-wk3-07.jpg'
