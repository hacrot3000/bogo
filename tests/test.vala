/* -*- indent-tabs-mode: nil; c-basic-offset: 2; tab-width: 2 -*- */

Gdk.EventKey create_event(unichar keyval,
                          bool pressed,
                          Gdk.ModifierType modifiers) {
  Gdk.EventKey e = (Gdk.EventKey) new Gdk.Event(
    pressed ? Gdk.EventType.KEY_PRESS : Gdk.EventType.KEY_RELEASE);

  e.send_event = 1;
  e.keyval = keyval;
  e.str = "";
  e.length = 0;
  e.state = modifiers;
  e.group = 0;
  e.is_modifier = 0;
  e.time = 0;

  return e;
}

class FakeInputContext : Bogo.InputContext, Object {
  public delegate bool ProcessKeyFunc(uint keyval, Gdk.ModifierType mods);
  public ProcessKeyFunc process_key_real;

  public bool process_key(uint keyval, Gdk.ModifierType mods) {
    if (process_key_real != null) {
      return process_key_real(keyval, mods);
    }
    return true;
  }

  public void reset() {
    
  }
}

void add_foo_tests () {
  Test.add_func("/bogoimcontext/delay committing until the last fake backspace release gets fed back", () => {
      var ic = new FakeInputContext();
      var ctx = new BogoIMContext("myapp", ic);

      ctx.delete_surrounding.connect(() => {
          // Not supporting deleting surrounding text
          return false;
        });

      int commit_count = 0;
      ctx.commit.connect(() => {
          commit_count++;
        });

      ic.process_key_real = () => {
        ic.composition_updated("ươ", 2);
        return true;
      };
      ctx.filter_keypress(create_event('w', true, 0));

      ctx.filter_keypress(create_event(0xff08, true, (Gdk.ModifierType) 1 << 25));
      assert(commit_count == 0);
      ctx.filter_keypress(create_event(0xff08, false, (Gdk.ModifierType) 1 << 25));
      assert(commit_count == 0);
      ctx.filter_keypress(create_event(0xff08, true, (Gdk.ModifierType) 1 << 25));
      assert(commit_count == 0);
      ctx.filter_keypress(create_event(0xff08, false, (Gdk.ModifierType) 1 << 25));
      assert(commit_count == 1);
    });
  
  Test.add_func("/bogoimcontext/fake GDK backspace event if surrounding text not supported", () => {
      var ic = new FakeInputContext();
      var ctx = new BogoIMContext("myapp", ic);

      int delete_surrounding_count = 0;
      ctx.delete_surrounding.connect(() => {
          // Not supporting deleting surrounding text
          delete_surrounding_count++;
          return false;
        });
      
      ic.process_key_real = () => {
        ic.composition_updated("ơ", 1);
        return true;
      };

      ctx.filter_keypress(create_event('w', true, 0));

      assert(delete_surrounding_count == 1);

      var e = Gdk.Event.get();
      assert(e != null);
      assert(e.type == Gdk.EventType.KEY_PRESS);
      assert(((Gdk.EventKey) e).keyval == 0xff08);

      e = Gdk.Event.get();
      assert(e != null);
      assert(e.type == Gdk.EventType.KEY_RELEASE);
      assert(((Gdk.EventKey) e).keyval == 0xff08);
    });
  
  Test.add_func("/bogoimcontext/fake backspaces requested while pending 1", () => {
      // The number of backspaces requested is more than the pending
      // commit string's length
      var ic = new FakeInputContext();
      var ctx = new BogoIMContext("firefox", ic);

      string committed_string = "";
      int commit_count = 0;
      ctx.commit.connect((str) => {
          commit_count++;
          committed_string = str;
        });

      // uơ -> ươi
      ic.process_key_real = () => {
        ic.composition_updated("ơ", 1);
        return true;
      };
      ctx.filter_keypress(create_event('w', true, 0));

      
      ic.process_key_real = () => {
        ic.composition_updated("ươi", 3);
        return true;
      };
      ctx.filter_keypress(create_event('i', true, 0));
      
      ctx.filter_keypress(create_event(0xff08, true, (Gdk.ModifierType) 1 << 25));
      ctx.filter_keypress(create_event(0xff08, true, (Gdk.ModifierType) 1 << 25));
      ctx.filter_keypress(create_event(0xff08, true, (Gdk.ModifierType) 1 << 25));
      ctx.filter_keypress(create_event(0xff08, false, Gdk.ModifierType.RELEASE_MASK | 1 << 25));

      assert(committed_string == "ươi");
      assert(commit_count == 1);
    });

  Test.add_func("/bogoimcontext/fake backspaces requested while pending 2", () => {
      // The number of backspaces requested is less than or equal to
      // the pending commit string's length
      var ic = new FakeInputContext();
      var ctx = new BogoIMContext("firefox", ic);

      string committed_string = "";
      int commit_count = 0;
      ctx.commit.connect((str) => {
          commit_count++;
          committed_string = str;
        });

      ic.process_key_real = () => {
        ic.composition_updated("êt", 2);
        return true;
      };

      // After this call, there should be 2 pending backspaces
      // and a delayed commit text of "êt"
      ctx.filter_keypress(create_event('a', true, 0));

      ic.process_key_real = () => {
        // This should replace the pending êt with ết
        ic.composition_updated("ết", 2);
        return true;
      };


      ctx.filter_keypress(create_event('a', true, 0));

      // The 2 fake backspaces from êt are fed back and triggers the delayed commit
      ctx.filter_keypress(create_event(0xff08, true, (Gdk.ModifierType) 1 << 25));
      ctx.filter_keypress(create_event(0xff08, false, Gdk.ModifierType.RELEASE_MASK | 1 << 25));
      ctx.filter_keypress(create_event(0xff08, true, (Gdk.ModifierType) 1 << 25));
      ctx.filter_keypress(create_event(0xff08, false, Gdk.ModifierType.RELEASE_MASK | 1 << 25));

      assert(committed_string == "ết");
      assert(committed_string != "êtết");
      assert(commit_count == 1);
    });
}


void main (string[] args) {
  Gtk.init (ref args);
  Test.init (ref args);
 
  Idle.add (() => {
      add_foo_tests ();
      Test.run ();
      Gtk.main_quit ();
      return false;
    });

  Gtk.main ();
}
