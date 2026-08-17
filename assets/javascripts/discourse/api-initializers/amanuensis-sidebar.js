import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

function buildLink(BaseCustomSidebarSectionLink, { name, href, title, icon }) {
  return class extends BaseCustomSidebarSectionLink {
    get name() {
      return name;
    }

    get href() {
      return href;
    }

    get title() {
      return title;
    }

    get text() {
      return title;
    }

    get prefixType() {
      return "icon";
    }

    get prefixValue() {
      return icon;
    }
  };
}

export default apiInitializer("1.8.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  if (!siteSettings.amanuensis_enabled) {
    return;
  }

  // /amanuensis/* is mostly still a plain server-rendered Rails engine, not
  // an Ember route. Without this, Discourse's global click handler tries to
  // resolve it client-side first and lands on Ember's own not-found page
  // instead of ever requesting the page from the server.
  //
  // EMBER_ROUTES lists the pages that have since been converted to real
  // Ember routes (see amanuensis-route-map.js) -- those should keep their
  // client-side transition rather than being forced through a full reload.
  // Append to this list as more pages get converted.
  const EMBER_ROUTES = ["/amanuensis/pipeline", "/amanuensis/outcomes"];

  api.registerValueTransformer(
    "full-page-refresh-on-navigation",
    ({ value, context }) => {
      const url = context?.url;
      if (!url?.startsWith("/amanuensis")) {
        return value;
      }
      if (EMBER_ROUTES.includes(url.split("?")[0])) {
        return value;
      }
      return true;
    }
  );

  const currentUser = api.getCurrentUser();
  if (!currentUser?.can_view_amanuensis) {
    return;
  }

  api.addSidebarSection((BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
    const linkDefs = [
      {
        name: "amanuensis-meetings",
        href: "/amanuensis/meetings",
        title: i18n("amanuensis.sidebar.meetings"),
        icon: "clipboard-list",
      },
      {
        name: "amanuensis-pipeline",
        href: "/amanuensis/pipeline",
        title: i18n("amanuensis.sidebar.pipeline"),
        icon: "list-check",
      },
      {
        name: "amanuensis-outcomes",
        href: "/amanuensis/outcomes",
        title: i18n("amanuensis.sidebar.outcomes"),
        icon: "flag-checkered",
      },
    ];

    if (currentUser.can_write_amanuensis) {
      linkDefs.push({
        name: "amanuensis-upload",
        href: "/amanuensis/uploads/new",
        title: i18n("amanuensis.sidebar.upload"),
        icon: "upload",
      });
    }

    const links = linkDefs.map(
      (def) => new (buildLink(BaseCustomSidebarSectionLink, def))()
    );

    return class extends BaseCustomSidebarSection {
      get name() {
        return "amanuensis";
      }

      get text() {
        return i18n("amanuensis.title");
      }

      get links() {
        return links;
      }
    };
  });
});
