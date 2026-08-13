import Sortable from "sortablejs"

export default {
  mounted() { this.init() },
  updated() { this.sortable?.destroy(); this.init() },
  destroyed() { this.sortable?.destroy() },

  init() {
    this.sortable = Sortable.create(this.el, {
      animation: 150,
      handle: ".drag-handle",
      ghostClass: "opacity-30",
      // Shared group name lets items move between containers while giving
      // the innermost matching container priority over parent containers.
      group: "study-blocks",
      onEnd: ({ item, from, to, oldIndex, newIndex }) => {
        if (from !== to || oldIndex !== newIndex) {
          this.pushEvent("reorder_node", {
            id: item.dataset.nodeId,
            from: from.id,
            to: to.id,
            new_index: String(newIndex)
          })
        }
      }
    })
  }
}
