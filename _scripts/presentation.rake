#dosya yoluyla methodu calıştırır
require 'pathname'
#dosya yoluyla pitonu yapılandırır
require 'pythonconfig'
#veri yapılarını olusturabılen dosya 
require 'yaml'
#site içerisindeki yapılandırmalara ait bölüm
CONFIG = Config.fetch('presentation', {})
#sunum dizinleri içerisindekileri yapılandırmak
PRESENTATION_DIR = CONFIG.fetch('directory', 'p')
#varsayılan dosyaları yapılandırmak
DEFAULT_CONFFILE = CONFIG.fetch('conffile', '_templates/presentation.cfg')
#sunum indekslerini dosyada oluşturmak
INDEX_FILE = File.join(PRESENTATION_DIR, 'index.html')
#görüntülenen resim boyutlar
IMAGE_GEOMETRY = [ 733, 550 ]
#hangi kaynaklara bakılacak bağımlılıklar
DEPEND_KEYS = %w(source css js)
#
DEPEND_ALWAYS = %w(media)
#hedef görevler ve tanımları
TASKS = {
    :index => 'sunumları indeksle',
    :build => 'sunumları oluştur',
    :clean => 'sunumları temizle',
    :view => 'sunumları görüntüle',
    :run => 'sunumları sun',
    :optim => 'resimleri iyileştir',
    :default => 'öntanımlı görev',
}
#tanım bilgileri
presentation = {}
#etiket bilgileri
tag = {}
#dosya isminde sınıf olusturmak
class File
#yenı dosyadan pdf üretimli kesin dosya yolu olusturmak
  @@absolute_path_here = Pathname.new(Pathname.pwd)
#hengi yolda oldugunu cagırmak
  def self.to_herepath(path)
#yeni olusturulan dosyaları genişletmek güvenli yol secimi yapmak
    Pathname.new(File.expand_path(path)).relative_path_from(@@absolute_path_here).to_s
  end
#yol olusturabılmek ıcın dosya lıstesını olusturmak
  def self.to_filelist(path)
#dizin dosyası olusturuldu mu?
    File.directory?(path) ?
#
      FileList[File.join(path, '*')].select { |f| File.file?(f) } :
      [path]
  end
end
#dosya/dizi yorumu yap
def png_comment(file, string)
#chunky_png kutuphanesını eklıyoruz
  require 'chunky_png'
#oily_png kutuphanesını eklıyoruz
  require 'oily_png'
#chunkyPNG adı altında dosya goruntusu resmi al

  image = ChunkyPNG::Image.from_file(file)
#komisyonda metaveriyi görüntüleyip yorumla
  image.metadata['Comment'] = 'raked'
#resımi kaydet
  image.save(file)
end
#png resimlerini optimize etmek
def png_optim(file, threshold=40000)
#alınması gereken degerlerden kucuk olanı kullanmak
  return if File.new(file).size < threshold
#optimize etmek
  sh "pngnq -f -e .png-nq #{file}"
#çıkışa gitmek
  out = "#{file}-nq"
  if File.exist?(out)
#isim karmaşıklıgı olursa giderilir
    $?.success? ? File.rename(out, file) : File.delete(out)
  end
  png_comment(file, 'raked')
end
#jpg resimli dosyaları optimize etmek
def jpg_optim(file)
#jpegoptim ve verilen dosyaları argumanlarla bırlıkte resmı optimize et
  sh "jpegoptim -q -m80 #{file}"
#son hali
  sh "mogrify -comment 'raked' #{file}"
end

def optim
#png ve jpq ıcın optım fonksıyonları
  pngs, jpgs = FileList["**/*.png"], FileList["**/*.jpg", "**/*.jpeg"]
# pngs,jpgs yı a kez dondur ekranda
  [pngs, jpgs].each do |a|
#optimize edilen resimleri almak
    a.reject! { |f| %x{identify -format '%c' #{f}} =~ /[Rr]aked/ }
  end
# ayrı ayrı resımler ıcın dondurmek
  (pngs + jpgs).each do |f|
#resimlerin boyutlarına bakar
    w, h = %x{identify -format '%[fx:w] %[fx:h]' #{f}}.split.map { |e| e.to_i }
#yenıden optımıze etmek
    size, i = [w, h].each_with_index.max
#eger resım goruntusunun boyutu kucukse
    if size > IMAGE_GEOMETRY[i]
#argumanları dondurur
      arg = (i > 0 ? 'x' : '') + IMAGE_GEOMETRY[i].to_s
      sh "mogrify -resize #{arg} #{f}"
    end
  end
#png resimler için
  pngs.each { |f| png_optim(f) }
#jpgs resimler için
  jpgs.each { |f| jpg_optim(f) }
#pngs,jpgs içinde dondur f defa
  (pngs + jpgs).each do |f|
    name = File.basename f
#md uzantılı dosyaları yazdır ve lıstele
    FileList["*/*.md"].each do |src|
#ekrana basmadan dosyaların olusturulması
      sh "grep -q '(.*#{name})' #{src} && touch #{src}"
    end
  end
end
#config dosyalarına bakmak
default_conffile = File.expand_path(DEFAULT_CONFFILE)
#karakter sunumlarının yapılandırmasını dondur
FileList[File.join(PRESENTATION_DIR, "[^_.]*")].each do |dir|
gelecek dosya dizinmidir
  next unless File.directory?(dir)
  chdir dir do
    name = File.basename(dir)
    conffile = File.exists?('presentation.cfg') ? 'presentation.cfg' : default_conffile
    config = File.open(conffile, "r") do |f|
      PythonConfig::ConfigParser.new(f)
    end
#landslide için yapılandırma
    landslide = config['landslide']
#tanımlanmamıssa
    if ! landslide
#ekranda hata cıktısı
      $stderr.puts "#{dir}: 'landslide' bölümü tanımlanmamış"
      exit 1
    end
#eger hedef ayarları ıse
    if landslide['destination']
#kullanılmıssa ekranda hata cıktısı bas
      $stderr.puts "#{dir}: 'destination' ayarı kullanılmış; hedef dosya belirtilmeyin"
      exit 1
    end
#md uzantılı dosya varsa
    if File.exists?('index.md')
      base = 'index'
#dısarı goster
      ispublic = true
#presentation.md dosyası var
    elsif File.exists?('presentation.md')
      base = 'presentation'
#dısarıyı gosterme
      ispublic = false
    else
#dıger durumlarda ekrana hata bas
      $stderr.puts "#{dir}: sunum kaynağı 'presentation.md' veya 'index.md' olmalı"
      exit 1
    end
#md dosyaları html ekle
    basename = base + '.html'
#ılk sayfaların png sını goster
    thumbnail = File.to_herepath(base + '.png')
    target = File.to_herepath(basename)

    deps = []
    (DEPEND_ALWAYS + landslide.values_at(*DEPEND_KEYS)).compact.each do |v|
      deps += v.split.select { |p| File.exists?(p) }.map { |p| File.to_filelist(p) }.flatten
    end
#kontrol etmek
    deps.map! { |e| File.to_herepath(e) }
#targeti silmek
    deps.delete(target)
#thumbnail sil
    deps.delete(thumbnail)

    tags = []

   presentation[dir] = {
      :basename => basename, # üreteceğimiz sunum dosyasının baz adı
      :conffile => conffile, # landslide konfigürasyonu (mutlak dosya yolu)
      :deps => deps, # sunum bağımlılıkları
      :directory => dir, # sunum dizini (tepe dizine göreli)
      :name => name, # sunum ismi
      :public => ispublic, # sunum dışarı açık mı
      :tags => tags, # sunum etiketleri
      :target => target, # üreteceğimiz sunum dosyası (tepe dizine göreli)
      :thumbnail => thumbnail, # sunum için küçük resim
    }
  end
end
#sunum dosyaları
presentation.each do |k, v|
#etiketli işlem
  v[:tags].each do |t|
    tag[t] ||= []
    tag[t] << k
  end
end
#gorev segmentı
tasktab = Hash[*TASKS.map { |k, v| [k, { :desc => v, :tasks => [] }] }.flatten]
#presentation içinde yapılandırma
presentation.each do |presentation, data|
#isim uzayı içinde
  ns = namespace presentation do
#içeriğiğni almak
    file data[:target] => data[:deps] do |t|
#sunumu hazırlamak
      chdir presentation do
        sh "landslide -i #{data[:conffile]}"
        sh 'sed -i -e "s/^\([[:blank:]]*var hiddenContext = \)false\(;[[:blank:]]*$\)/\1true\2/" presentation.html'
        unless data[:basename] == 'presentation.html'
#ismi düzenlemek
          mv 'presentation.html', data[:basename]
        end
      end
    end
#resmi hedefle
    file data[:thumbnail] => data[:target] do
#sonraki public deilse
      next unless data[:public]
      sh "cutycapt " +
          "--url=file://#{File.absolute_path(data[:target])}#slide1 " +
          "--out=#{data[:thumbnail]} " +
          "--user-style-string='div.slides { width: 900px; overflow: hidden; }' " +# resimleri duzenle
          "--min-width=1024 " +
          "--min-height=768 " +
          "--delay=1000"
#yenıden boyutlandırma
      sh "mogrify -resize 240 #{data[:thumbnail]}"
#optımıze etmek
      png_optim(data[:thumbnail])
    end
#optımı gorevı
    task :optim do
#dızın degıstırme
      chdir presentation do
        optim
      end
    end
#indeksi resim için data et
    task :index => data[:thumbnail]
#build görevini uygulama
    task :build => [:optim, data[:target], :index]

    task :view do
#istedıgımız dosya varmı
      if File.exists?(data[:target])
#ıstedıgımız dosya varsa gereklı dosyaları olustur
        sh "touch #{data[:directory]}; #{browse_command data[:target]}"
      else
# ıstedıgımız dosya yoksa ekrana hata bassın
        $stderr.puts "#{data[:target]} bulunamadı; önce inşa edin"
      end
    end
#buıld ve vıew calıstırma
    task :run => [:build, :view]
#temızleme
    task :clean do
#dosyaları ve resımlerı temızleme
      rm_f data[:target]
      rm_f data[:thumbnail]
    end
#rake ınsa etmek
    task :default => :build
  end
# verilen gorevlerın eklenmesı
  ns.tasks.map(&:to_s).each do |t|
    _, _, name = t.partition(":").map(&:to_sym)
    next unless tasktab[name]
    tasktab[name][:tasks] << t
  end
end
#ısımuzayında isim ve bilgileri tanımlama
namespace :p do
  tasktab.each do |name, info|
    desc info[:desc]
    task name => info[:tasks]
    task name[0] => name
  end

  task :build do
#ındeks fıle yuklenmesı
    index = YAML.load_file(INDEX_FILE) || {}
#sunumdosyası olusturulması
    presentations = presentation.values.select { |v| v[:public] }.map { |v| v[:directory] }.sort
#degerleri esıt degılse
    unless index and presentations == index['presentations']
      index['presentations'] = presentations
      File.open(INDEX_FILE, 'w') do |f|
#ındex.to_yaml yazdır
        f.write(index.to_yaml)
#sonuna \n ekle
        f.write("---\n")
      end
    end
  end
# menulerı sırala sec
  desc "sunum menüsü"
  task :menu do
    lookup = Hash[
      *presentation.sort_by do |k, v|
        File.mtime(v[:directory])
      end
#terscevırme
      .reverse
      .map { |k, v| [v[:name], k] }
      .flatten
    ]
#menu sec baslık renk default degerı
    name = choose do |menu|
      menu.default = "1"
      menu.prompt = color(
        'Lütfen sunum seçin ', :headline
      ) + '[' + color("#{menu.default}", :special) + ']'
      menu.choices(*lookup.keys)
    end
    directory = lookup[name]
#rake et
    Rake::Task["#{directory}:run"].invoke
  end
#menu gorevı 
  task :m => :menu
end

desc "sunum menüsü"
#sunum gorevlerı
task :p => ["p:menu"]

task :presentation => :p
