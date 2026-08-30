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

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  if (!siteSettings.amanuensis_enabled) {
    return;
  }

  // #23 added a full-page-refresh-on-navigation transformer here, back when
  // /amanuensis/* was a plain server-rendered Rails engine and Ember's
  // client-side router would resolve a sidebar click before the request
  // ever reached the server, landing on Ember's own not-found page. Every
  // /amanuensis/* page is a real Ember route now (see
  // amanuensis-route-map.js), so that workaround no longer has anything
  // left to work around -- removed rather than carried forward as an
  // always-matching allowlist.

  const currentUser = api.getCurrentUser();
  if (!currentUser?.can_view_amanuensis) {
    return;
  }

  api.addSidebarSection(
    (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
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
    }
  );
});
