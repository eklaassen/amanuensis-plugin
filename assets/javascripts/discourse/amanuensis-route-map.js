// Registers each converted /amanuensis/* page as a top-level Ember route, so
// it renders inside Discourse's normal app shell (header, sidebar, theme
// CSS) instead of the plain server-rendered HTML the rest of
// app/views/amanuensis still uses. No `resource` key here -- that's only
// for nesting under an existing resource (e.g. admin's plugin pages); a
// bare `this.route()` call maps straight onto the application route, same
// as core pages like /badges.
export default function () {
  this.route("amanuensis-pipeline", { path: "/amanuensis/pipeline" });
  this.route("amanuensis-stage-runs", { path: "/amanuensis/stages/:stage" });
  this.route("amanuensis-stage-run", { path: "/amanuensis/stages/:stage/runs/:run_id" });
  this.route("amanuensis-outcomes", { path: "/amanuensis/outcomes" });
}
