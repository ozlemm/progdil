require 'yaml'
require 'erb'

task :exam =>[:md, :pdf]

task :md do


  Dir["_exams/*.yml"].each do |i|
	s=YAML.load(File.open(i))
	s_Markdown="_exams/#{File.basename(i).split("'.')[0]}.md"
  File.open(s_Markdown,"w") do |f|
    f.puts "# # {s['title']}"
    s['q'].collect do |sorular|
	f.puts "- #{Fileread("_includes/q/#{sorular}")}\n\n"
    end
end
end

task :pdf do
	Dir["_exams/*.md"].each do |i|
	  s_adi = "_exams/#{File.basename(i).split('.')[0]}"
	  sh "markdown2pdf #{s_adi}.md > #{s_adi}.pdf"
	end
end


 
        
	
