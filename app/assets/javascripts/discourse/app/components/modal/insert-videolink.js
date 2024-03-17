import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { prefixProtocol } from "discourse/lib/url";

export default class InsertVideolink extends Component {
    @tracked linkText = this.args.model.linkText;
    @tracked linkUrl = "";
    @tracked selectedRow = -1;

    willDestroy() {
        super.willDestroy(...arguments);
    }

    @action
    ok() {
        const origLink = this.linkUrl;
        const linkUrl = prefixProtocol(origLink);
        const sel = this.args.model.toolbarEvent.selected;

        if (isEmpty(linkUrl)) {
            return;
        }


        if (sel.value) {
            this.args.model.toolbarEvent.addText(`${linkUrl}`);
        } else {
            this.args.model.toolbarEvent.addText(`${linkUrl}`);
            this.args.model.toolbarEvent.selectText(sel.start + 1, origLink.length);
        }
        
        this.args.closeModal();
    }

    @action
    linkClick(e) {
        if (!e.metaKey && !e.ctrlKey) {
            e.preventDefault();
            e.stopPropagation();
            this.selectLink(e.target.closest(".search-link"));
        }
    }

    @action
    updateLinkVoid(event) {
        this.linkUrl = event.target.value;
    }
}
