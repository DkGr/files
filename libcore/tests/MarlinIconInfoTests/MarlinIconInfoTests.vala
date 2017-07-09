/*
* Copyright (c) 2017 elementary LLC
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 59 Temple Place - Suite 330,
* Boston, MA 02111-1307, USA.
*
* Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

void add_icon_info_tests () {
    Test.add_func ("/MarlinIconInfo/goffile_icon_update", goffile_icon_update_test);
    Test.add_func ("/MarlinIconInfo/cache_and_ref", cache_and_ref_test);
    Test.add_func ("/MarlinIconInfo/lookup_from_path_svg", lookup_from_path_svg_test);
    Test.add_func ("/MarlinIconInfo/lookup_from_path_jpg", lookup_from_path_jpg_test);
    Test.add_func ("/MarlinIconInfo/lookup_from_path_png", lookup_from_path_png_test);
    Test.add_func ("/MarlinIconInfo/pixbuf_at_size_test", pixbuf_at_size_test);
    Test.add_func ("/MarlinIconInfo/lookup_from_name", lookup_from_name_test);
}

void goffile_icon_update_test () {
    string test_file_path = Path.build_filename (Config.TESTDATA_DIR, "images", "testimage.png");
    GOF.File file = GOF.File.get_by_uri (test_file_path);
    assert (file != null);
    file.query_update ();
    assert (file.pix == null);
    file.update_icon (128);
    assert (file.pix != null);
    assert (file.pix_size == 128);
    file.update_icon (32);
    assert (file.pix_size == 32);
}

void cache_and_ref_test () {
    Marlin.IconInfo.clear_caches ();
    uint reap_time_msec = 20; //Must be higher than 10.
    Marlin.IconInfo.set_reap_time (reap_time_msec);

    string test_file_path = Path.build_filename (Config.TESTDATA_DIR, "images", "testimage.jpg");
    GOF.File file = GOF.File.get_by_uri (test_file_path);
    assert (file != null);
    file.query_update ();

    assert (file.pix == null);
    file.update_icon (128);
    assert (file.pix.ref_count == 2); //Ref'd by file and a toggle ref.

    /* We have not flagged THUMBNAIL_READY so a themed icon will be created */
    assert (Marlin.IconInfo.themed_icon_cache_info () == 1);
    assert (Marlin.IconInfo.loadable_icon_cache_info () == 0);

    file.update_icon (32);

    /* A new cache entry is made for different size */
    assert (Marlin.IconInfo.themed_icon_cache_info () == 2);

    /* IconInfo should remain in case for 6 * reap_time_msec */
    var loop = new MainLoop ();
    Timeout.add (reap_time_msec * 2, () => {
        /* Icons should NOT be reaped yet */
        assert (Marlin.IconInfo.themed_icon_cache_info () == 1);
        loop.quit ();
        return false;
    });
    loop.run ();

    file.pix = null;

    loop = new MainLoop ();
    Timeout.add (reap_time_msec * 12, () => {
        /* Icon should be reaped by now */
        assert (Marlin.IconInfo.themed_icon_cache_info () == 0);
        loop.quit ();
        return false;
    });
    loop.run ();
}

void lookup_from_path_svg_test () {
    /* Test file is 32 X 32 px*/
    string test_file_path = Path.build_filename (Config.TESTDATA_DIR, "images", "testimage.svg");
    lookup_from_path (test_file_path, 64);
}

void lookup_from_path_jpg_test () {
    /* Test file is 3000 x 1688 px */
    string test_file_path = Path.build_filename (Config.TESTDATA_DIR, "images", "testimage.jpg");
    lookup_from_path (test_file_path, 128);
}

void lookup_from_path_png_test () {
    /* Test file is 144 x 256 px */
    string test_file_path = Path.build_filename (Config.TESTDATA_DIR, "images", "testimage.png");
    lookup_from_path (test_file_path, 256);
}

void pixbuf_at_size_test () {
    Marlin.IconInfo.clear_caches ();

    string test_file_path = Path.build_filename (Config.TESTDATA_DIR, "images", "testimage.svg");
    Gdk.Pixbuf? pix = null;

    try {
        pix = new Gdk.Pixbuf.from_file (test_file_path);
    } catch (Error e) {
        assert_not_reached ();
    }

    double aspect = (double)(pix.get_height ()) / (double)(pix.get_width ());
    var marlin_icon = Marlin.IconInfo.lookup_from_path (test_file_path, 32);

    assert (check_pixbuf_dimension (marlin_icon.get_pixbuf_nodefault (), 32, aspect));
    assert (check_pixbuf_dimension (marlin_icon.get_pixbuf_at_size (24), 24, aspect));
    assert (check_pixbuf_dimension (marlin_icon.get_pixbuf_at_size (128), 128, aspect));
    assert (marlin_icon.get_pixbuf_at_size (0) == null);

    /* Getting (temporary) scaled pixbufs does not create new iconinfo nor increase pixbuf refcount */
    assert (Marlin.IconInfo.themed_icon_cache_info () == 0);
    assert (Marlin.IconInfo.loadable_icon_cache_info () == 1);
    assert (marlin_icon.ref_count == 2);
    assert (marlin_icon.get_pixbuf_ref_count () == 2);
}

Marlin.IconInfo? lookup_from_path (string test_file_path, int size) {
    Marlin.IconInfo.clear_caches ();

    var marlin_icon = Marlin.IconInfo.lookup_from_path (test_file_path, size);
    assert (Marlin.IconInfo.themed_icon_cache_info () == 0);
    assert (Marlin.IconInfo.loadable_icon_cache_info () == 1);
    assert (marlin_icon.ref_count == 2);
    assert (marlin_icon.get_pixbuf_ref_count () == 2);

    return marlin_icon;
}

bool check_pixbuf_dimension (Gdk.Pixbuf pix, int size, double aspect) {
    if (aspect <= 1.0) {
        return (pix.width == size && pix.height == (int)(size * aspect));
    } else {
        return (pix.height == size && pix.width == (int)(size / aspect));
    }
}

int main (string[] args) {
    Test.init (ref args);

    add_icon_info_tests ();

    return Test.run ();
}
