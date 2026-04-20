//// The fiction is the definition of a story.
//// It contains defintions for all the storylets and qualities.
//// It contains no player state and minimal runtime logic.

import tiff/fiction/quality.{type Quality}
import tiff/fiction/storylet.{type Storylet}

pub type Fiction {
  Fiction(storylets: List(Storylet), qualities: List(Quality))
}
