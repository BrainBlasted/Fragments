using Gtk;

class Fragments.TorrentListBox : ListBox {

	private ListBoxRow? hover_row;
	private ListBoxRow? drag_row;
	private bool top = false;
	private int hover_top;
	private int hover_bottom;

	private bool rearrangeable;

	const TargetEntry[] entries = {
		{ "GTK_LIST_BOX_ROW", Gtk.TargetFlags.SAME_APP, 0}
	};

	public TorrentListBox (bool rearrangeable) {
		this.rearrangeable = rearrangeable;

		if(rearrangeable) drag_dest_set (this, Gtk.DestDefaults.ALL, entries, Gdk.DragAction.MOVE);

		this.set_selection_mode(SelectionMode.NONE);
		this.get_style_context ().add_class ("transparent");
	}

	private void row_drag_begin (Widget widget, Gdk.DragContext context) {
		Torrent row = (Torrent) widget.get_ancestor (typeof (Torrent));
		Allocation alloc;
		row.get_allocation (out alloc);

		TorrentListBox parent = row.get_parent () as TorrentListBox;

		Cairo.Surface surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, alloc.width, alloc.height);
		Cairo.Context cr = new Cairo.Context (surface);
		int x, y;

		if (parent != null) parent.drag_row = row;

		row.get_style_context ().add_class ("dragging");
		row.draw (cr);
		row.get_style_context ().remove_class ("dragging");

		widget.translate_coordinates (row, 0, 0, out x, out y);
		surface.set_device_offset (-x, -y);
		drag_set_icon_surface (context, surface);
	}

	public override bool drag_motion (Gdk.DragContext context, int x, int y, uint time_) {
		if (!(y > hover_top || y < hover_bottom)) return true;

		Allocation alloc;
		var row = get_row_at_y (y);
		bool old_top = top;

		row.get_allocation (out alloc);
		int hover_row_y = alloc.y;
		int hover_row_height = alloc.height;
		if (row != drag_row) {
			if (y < hover_row_y + hover_row_height/2) {
				hover_top = hover_row_y;
				hover_bottom = hover_top + hover_row_height/2;
				row.get_style_context ().add_class ("drag-hover-top");
				row.get_style_context ().remove_class ("drag-hover-bottom");
				top = true;
			} else {
				hover_top = hover_row_y + hover_row_height/2;
				hover_bottom = hover_row_y + hover_row_height;
				row.get_style_context ().add_class ("drag-hover-bottom");
				row.get_style_context ().remove_class ("drag-hover-top");
				top = false;
			}
		}

		if (hover_row != null && hover_row != row) {
			if (old_top) hover_row.get_style_context ().remove_class ("drag-hover-top");
			else hover_row.get_style_context ().remove_class ("drag-hover-bottom");
		}

		hover_row = row;
		return true;
	}

	private void row_drag_data_get (Widget widget, Gdk.DragContext context, SelectionData selection_data, uint info, uint time_) {
		uchar[] data = new uchar[(sizeof (Widget))];
		((Widget[])data)[0] = widget;
		selection_data.set (Gdk.Atom.intern_static_string ("GTK_LIST_BOX_ROW"), 32, data);
	}

	public override void drag_data_received (Gdk.DragContext context, int x, int y, SelectionData selection_data, uint info, uint time_) {
		Widget handle;
		ListBoxRow row;

		int index = 0;
		if (hover_row != null) {
			if (top) {
				index = hover_row.get_index ();
				if(index == -1) index = 0;
				hover_row.get_style_context ().remove_class ("drag-hover-top");
			} else {
				index = hover_row.get_index ();
				hover_row.get_style_context ().remove_class ("drag-hover-bottom");
			}
			handle = ((Widget[])selection_data.get_data ())[0];
			row = (ListBoxRow) handle.get_ancestor (typeof (ListBoxRow));

			if (row != hover_row) {
				row.get_parent ().remove (row);
				insert (row, index);
				update_index_number();
			}
		}
		drag_row = null;
	}

	private void update_index_number(){
		this.@foreach ((torrent) => {
			((Torrent)torrent).index_label.set_text((((Torrent)torrent).get_index()+1).to_string());
		});
	}

	public void add_torrent (Torrent row, int pos) {
		if(rearrangeable){
			drag_source_set (row.eventbox, Gdk.ModifierType.BUTTON1_MASK, entries, Gdk.DragAction.MOVE);
			row.eventbox.drag_begin.connect (row_drag_begin);
			row.eventbox.drag_data_get.connect (row_drag_data_get);
			row.show_index_number = true;
		}

		this.insert(row, pos);
		update_index_number();
	}

	public void remove_torrent (Torrent row) {
		if(rearrangeable){
			drag_source_unset (row.eventbox);
			row.eventbox.drag_begin.disconnect (row_drag_begin);
			row.eventbox.drag_data_get.disconnect (row_drag_data_get);
			row.show_index_number = false;
		}

		this.remove(row);
		update_index_number();
	}
}