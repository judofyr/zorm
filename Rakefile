require 'rake/clean'


PANDOCS_OPTS = [
  "--standalone",
  "--toc",
  "--to", "html5",
  "--css", "style.css",
  "--variable", "pagetitle:Zorm",
]

desc 'Generate documentation using Pandoc'
task :docs

DOCS = {
  "index" => %w[index motivation concepts],
}

DOCS.each do |target, source|
  target = "docs-html/#{target}.html"
  source = source.map { |x| "docs/#{x}.md" }

  task :docs do
    sh "pandoc", *PANDOCS_OPTS, "--output", target, *source

    puts "patching #{target}"
    data = File.read(target).gsub(/<a href="#TOC">(.*?)<\/a>/) { $1 }
    File.write(target, data)
  end
end

