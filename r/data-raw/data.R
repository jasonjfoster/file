data_forms <- read.csv("data-raw/forms.csv")
save(data_forms, file = "data/data_forms.rda")

data_items <- read.csv("data-raw/items.csv", colClasses = c(item = "character"))
save(data_items, file = "data/data_items.rda")
