/// Default categories and built-in phrases seeded for learner, parent, and teacher accounts.
///
/// Phrases use short AAC-style labels (single words or very short phrases) so
/// pictures map directly to what the child sees and taps.
abstract final class DefaultBuiltinContent {
  static const defaultCategories = <(String key, String name, String iconKey)>[
    ('feelings', 'Feelings', 'feelings'),
    ('food', 'Food', 'food'),
    ('drinks', 'Drinks', 'drinks'),
    ('activities', 'Activities', 'activities'),
    ('animals', 'Animals', 'animals'),
    ('needs', 'Needs', 'needs'),
    ('greetings', 'Greetings', 'greetings'),
    ('school', 'School', 'school'),
    ('places', 'Places', 'places'),
  ];

  /// (label, category key, bundled image filename)
  static const defaultPhrases =
      <(String text, String categoryKey, String imageFile)>[
    // Feelings — clear face / body cues
    ('Happy', 'feelings', 'phrase_happy.jpg'),
    ('Sad', 'feelings', 'phrase_sad.jpg'),
    ('Angry', 'feelings', 'phrase_angry.jpg'),
    ('Scared', 'feelings', 'phrase_scared.jpg'),
    ('Tired', 'feelings', 'phrase_tired.jpg'),
    ('Sick', 'feelings', 'phrase_sick.jpg'),
    ('Hot', 'feelings', 'phrase_hot.jpg'),
    ('Cold', 'feelings', 'phrase_cold.jpg'),
    ('Hungry', 'feelings', 'phrase_hungry.jpg'),
    ('Sleepy', 'feelings', 'phrase_sleepy.jpg'),
    // Food — the food itself
    ('Pizza', 'food', 'phrase_pizza.jpg'),
    ('Rice', 'food', 'phrase_rice.jpg'),
    ('Bread', 'food', 'phrase_bread.jpg'),
    ('Chicken', 'food', 'phrase_chicken.jpg'),
    ('Apple', 'food', 'phrase_apple.jpg'),
    ('Banana', 'food', 'phrase_banana.jpg'),
    ('Vegetables', 'food', 'phrase_vegetables.jpg'),
    ('Eggs', 'food', 'phrase_eggs.jpg'),
    ('Cake', 'food', 'phrase_cake.jpg'),
    ('Sandwich', 'food', 'phrase_sandwich.jpg'),
    // Drinks
    ('Water', 'drinks', 'phrase_water.jpg'),
    ('Milk', 'drinks', 'phrase_milk.jpg'),
    ('Juice', 'drinks', 'phrase_juice.jpg'),
    ('Soda', 'drinks', 'phrase_soda.jpg'),
    ('Coffee', 'drinks', 'phrase_coffee.jpg'),
    ('Tea', 'drinks', 'phrase_tea.jpg'),
    ('Ice cream', 'drinks', 'phrase_ice_cream.jpg'),
    // Activities
    ('Sleep', 'activities', 'phrase_sleep.jpg'),
    ('Play', 'activities', 'phrase_play.jpg'),
    ('Eat', 'activities', 'phrase_eat.jpg'),
    ('Home', 'activities', 'phrase_home.jpg'),
    ('TV', 'activities', 'phrase_tv.jpg'),
    ('Read', 'activities', 'phrase_read.jpg'),
    ('Draw', 'activities', 'phrase_draw.jpg'),
    ('Dance', 'activities', 'phrase_dance.jpg'),
    ('Swim', 'activities', 'phrase_swim.jpg'),
    ('Run', 'activities', 'phrase_run.jpg'),
    // Animals — the animal only
    ('Dog', 'animals', 'phrase_dog.jpg'),
    ('Cat', 'animals', 'phrase_cat.jpg'),
    ('Bird', 'animals', 'phrase_bird.jpg'),
    ('Fish', 'animals', 'phrase_fish.jpg'),
    ('Cow', 'animals', 'phrase_cow.jpg'),
    ('Horse', 'animals', 'phrase_horse.jpg'),
    ('Rabbit', 'animals', 'phrase_rabbit.jpg'),
    ('Butterfly', 'animals', 'phrase_butterfly.jpg'),
    // Needs
    ('Help', 'needs', 'phrase_help.jpg'),
    ('Bathroom', 'needs', 'phrase_bathroom.jpg'),
    ('Break', 'needs', 'phrase_break.jpg'),
    ('Medicine', 'needs', 'phrase_medicine.jpg'),
    ('Rest', 'needs', 'phrase_rest.jpg'),
    ('Quiet', 'needs', 'phrase_quiet.jpg'),
    ('Hurt', 'needs', 'phrase_hurt.jpg'),
    ('Glasses', 'needs', 'phrase_glasses.jpg'),
    // Greetings
    ('Hello', 'greetings', 'phrase_hello.jpg'),
    ('Goodbye', 'greetings', 'phrase_goodbye.jpg'),
    ('Thank you', 'greetings', 'phrase_thank_you.jpg'),
    ('Please', 'greetings', 'phrase_please.jpg'),
    ('Yes', 'greetings', 'phrase_yes.jpg'),
    ('No', 'greetings', 'phrase_no.jpg'),
    ('More', 'greetings', 'phrase_more.jpg'),
    ('Stop', 'greetings', 'phrase_stop.jpg'),
    ('Sorry', 'greetings', 'phrase_sorry.jpg'),
    // School
    ('School', 'school', 'phrase_school.jpg'),
    ('Homework', 'school', 'phrase_homework.jpg'),
    ('Pencil', 'school', 'phrase_pencil.jpg'),
    ('Book', 'school', 'phrase_book.jpg'),
    ('Recess', 'school', 'phrase_recess.jpg'),
    ('Teacher', 'school', 'phrase_teacher.jpg'),
    ('Headache', 'school', 'phrase_headache.jpg'),
    ('Sick day', 'school', 'phrase_sick_day.jpg'),
    // Places
    ('Park', 'places', 'phrase_park.jpg'),
    ('Store', 'places', 'phrase_store.jpg'),
    ('Hospital', 'places', 'phrase_hospital.jpg'),
    ('Outside', 'places', 'phrase_outside.jpg'),
    ('Bedroom', 'places', 'phrase_bedroom.jpg'),
    ('Classroom', 'places', 'phrase_classroom.jpg'),
  ];

  static String imageAsset(String imageFile) => 'assets/images/$imageFile';

  static String? imagePathForEntry((String, String, String) entry) =>
      imageAsset(entry.$3);
}
