import tiff/fiction/quality.{type Quality}
import tiff/fiction/storylet.{type Storylet}

pub type Fiction {
  Fiction(storylets: List(Storylet), qualities: List(Quality))
}
