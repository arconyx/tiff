import tiff/fiction/choice.{type Choice}

pub type Storylet {
  Storylet(id: String, body: List(String), choices: List(Choice))
}
