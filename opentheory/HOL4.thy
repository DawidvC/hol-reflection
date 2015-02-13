show: "Data.Bool"
bool-int { package: bool-int-1.17 }
bool-ext { import: bool-int package: bool-ext-1.12 }
bool-class { import: bool-int import: bool-ext package: bool-class-1.26 }
himp {
  import: bool-int
  import: bool-ext
  import: bool-class
  article: "HOL4Imp.art"
}
hbool {
  import: bool-int
  import: bool-ext
  import: bool-class
  import: himp
  article: "HOL4Bool.art"
}
hsat {
  import: bool-int
  import: bool-ext
  import: bool-class
  import: hbool
  import: himp
  article: "HOL4Sat.art"
}
main {
  import: bool-int
  import: bool-class
  import: bool-ext
  import: hbool
  import: himp
  import: hsat
}
