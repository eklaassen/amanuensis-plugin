// The read-only API controllers (Meetings/Pipeline/Stages/Outcomes) render
// { error: "..." } on upstream failure with a real (non-2xx) status now, so
// ajax() rejects instead of resolving. Route model() hooks have no error
// substate UI here -- the templates already know how to render an inline
// AmanuensisError banner from a model.error string -- so each route's
// .catch() uses this to rebuild that same shape from the rejection instead
// of letting Ember fall through to its generic broken-page error substate.
//
// discourse/lib/ajax-error's extractError() doesn't fit: it reads the
// { errors: [...] } array shape (matching UploadsApiController's write
// endpoints), not the singular { error: "..." } string these read
// endpoints render. Checked in both of the shapes ajax() rejections have
// carried across Discourse versions -- the raw jqXHR, and jqXHR wrapped as
// { jqXHR, textStatus, errorThrown } -- rather than assuming just one.
export default function modelErrorFrom(error, fallbackMessage) {
  const body = error?.jqXHR?.responseJSON ?? error?.responseJSON;
  return { error: body?.error || fallbackMessage };
}
