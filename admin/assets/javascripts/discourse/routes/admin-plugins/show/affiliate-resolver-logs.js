import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AffiliateResolverLogsRoute extends DiscourseRoute {
  titleToken() {
    return i18n("affiliate_resolver.logs.title");
  }

  setupController(controller) {
    super.setupController(...arguments);
    controller.resetState();
    controller.loadLogs();
  }
}
