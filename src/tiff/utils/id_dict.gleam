//// `IdDict` is a dictionary wrapper for storing lists of objects that have
//// an id field in such a way that we get to benefit from the fast lookups of
//// hash tables.
////
//// It is read-only because that is all we need.
//// We could support mutability by embedding the key function but then
//// we have to figure out a decoder for a function.

import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/list
import gleam/order

/// A dictionary where the keys are derived from the
/// value.
///
/// This is a wrapper around `dict.Dict`.
pub opaque type IdDict(k, v) {
  IdDict(dict: Dict(k, v))
}

pub fn id_dict_decoder(
  key_decoder: decode.Decoder(k),
  value_decoder: decode.Decoder(v),
) -> decode.Decoder(IdDict(k, v)) {
  use dict <- decode.field("dict", decode.dict(key_decoder, value_decoder))
  decode.success(IdDict(dict:))
}

/// Generate a dictionary where the key is derived from the value
/// using the given key function.
///
/// The key function is assumed to be pure.
///
/// This behaves like `dict.from_list` so in the case of duplicate
/// keys the last value with be used.
pub fn from_list(list: List(v), key: fn(v) -> k) -> IdDict(k, v) {
  list
  |> list.map(fn(li) { #(key(li), li) })
  |> dict.from_list
  |> IdDict
}

/// Turn a dictionary into a list of values sorted by key.
///
/// Sorting is mandated so that the results are stable.
pub fn to_list(dict: IdDict(k, v), sort_by: fn(k, k) -> order.Order) -> List(v) {
  dict.dict
  |> dict.to_list
  |> list.sort(by: fn(a, b) { sort_by(a.0, b.0) })
  |> list.map(fn(a) { a.1 })
}

pub fn get(dict: IdDict(k, v), key: k) -> Result(v, Nil) {
  dict.dict
  |> dict.get(key)
}

pub fn none() -> IdDict(k, v) {
  dict.new() |> IdDict
}
