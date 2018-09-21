using Toybox.WatchUi as Ui;

class HelicopterDelegate extends Ui.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onMenu() {
        Ui.pushView(new Rez.Menus.MainMenu(), new HelicopterMenuDelegate(), Ui.SLIDE_UP);
        return true;
    }

}