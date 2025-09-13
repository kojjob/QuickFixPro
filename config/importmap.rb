# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Dashboard visualization libraries
pin "chart.js", to: "https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"
pin "d3", to: "https://cdn.jsdelivr.net/npm/d3@7.8.5/dist/d3.min.js"
pin "chartjs-plugin-annotation", to: "https://cdn.jsdelivr.net/npm/chartjs-plugin-annotation@3.0.1/dist/chartjs-plugin-annotation.min.js"
