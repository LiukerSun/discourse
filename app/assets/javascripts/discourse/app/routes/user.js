import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import User from "discourse/models/user";
import DiscourseRoute from "discourse/routes/discourse";
import { bind } from "discourse-common/utils/decorators";

export default DiscourseRoute.extend({
  router: service(),
  searchService: service("search"),
  appEvents: service("app-events"),
  messageBus: service("message-bus"),

  beforeModel() {
    if (this.siteSettings.hide_user_profiles_from_public && !this.currentUser) {
      this.router.replaceWith("discovery");
    }
  },

  model(params) {
    // If we're viewing the currently logged in user, return that object instead
    if (
      this.currentUser &&
      params.username.toLowerCase() === this.currentUser.username_lower
    ) {
      return this.currentUser;
    }

    return User.create({
      username: encodeURIComponent(params.username),
    });
  },

  afterModel() {
    const user = this.modelFor("user");

    return user
      .findDetails()
      .then(() => user.findStaffInfo())
      .then(() => user.statusManager.trackStatus())
      .catch(() => this.router.replaceWith("/404"));
  },

  serialize(model) {
    if (!model) {
      return {};
    }

    return { username: (model.username || "").toLowerCase() };
  },

  setupController(controller, user) {
    controller.set("model", user);
    this.searchService.searchContext = user.searchContext;
  },

  activate() {
    this._super(...arguments);

    const user = this.modelFor("user");
    this.messageBus.subscribe(`/u/${user.username_lower}`, this.onUserMessage);
    this.messageBus.subscribe(
      `/u/${user.username_lower}/counters`,
      this.onUserCountersMessage
    );
  },

  deactivate() {
    this._super(...arguments);

    const user = this.modelFor("user");
    this.messageBus.unsubscribe(
      `/u/${user.username_lower}`,
      this.onUserMessage
    );
    this.messageBus.unsubscribe(
      `/u/${user.username_lower}/counters`,
      this.onUserCountersMessage
    );
    user.statusManager.stopTrackingStatus();

    // Remove the search context
    this.searchService.searchContext = null;
  },

  @bind
  onUserMessage(data) {
    const user = this.modelFor("user");
    return user.loadUserAction(data);
  },

  @bind
  onUserCountersMessage(data) {
    const user = this.modelFor("user");
    user.setProperties(data);

    Object.entries(data).forEach(([key, value]) =>
      this.appEvents.trigger(
        `count-updated:${user.username_lower}:${key}`,
        value
      )
    );
  },

  titleToken() {
    const username = this.modelFor("user").username;
    return username ? username : null;
  },

  @action
  undoRevokeApiKey(key) {
    key.undoRevoke();
  },

  @action
  revokeApiKey(key) {
    key.revoke();
  },
});
