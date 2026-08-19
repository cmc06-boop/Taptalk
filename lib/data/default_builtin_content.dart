/// Default categories and built-in phrases seeded for learner, parent, and teacher accounts.
///
/// Categories match folder names under [assets/images]; phrase labels match image filenames.
abstract final class DefaultBuiltinContent {
  static const defaultCategories = <(String key, String name, String iconKey)>[
    ('feelings', 'Feelings', 'feelings'),
    ('needs', 'Needs', 'needs'),
    ('food', 'Food', 'food'),
    ('drinks', 'Drinks', 'drinks'),
    ('school', 'School', 'school'),
    ('responses', 'Responses', 'custom'),
    ('health_safety', 'Health & Safety', 'custom'),
    ('family', 'Family', 'custom'),
    ('activities', 'Activities', 'activities'),
    ('hobbies', 'Hobbies', 'custom'),
    ('greetings', 'Greetings', 'greetings'),
    ('animals', 'Animals', 'animals'),
    ('colors', 'Colors', 'custom'),
    ('places', 'Places', 'places'),
    ('transportation', 'Transportation', 'custom'),
    ('technology', 'Technology', 'custom'),
  ];

  static const categoryDisplayOrder = <String>[
    'feelings',
    'needs',
    'food',
    'drinks',
    'school',
    'responses',
    'health_safety',
    'family',
    'activities',
    'hobbies',
    'greetings',
    'animals',
    'colors',
    'places',
    'transportation',
    'technology',
  ];

  /// Subcategories for Food and Drinks (key, name, parent key, icon key).
  static const defaultSubcategories =
      <(String key, String name, String parentKey, String iconKey)>[
    ('food_fruits', 'Fruits', 'food', 'food_fruits'),
    ('food_vegetables', 'Vegetables', 'food', 'food_vegetables'),
    ('food_dessert', 'Dessert', 'food', 'food_dessert'),
    ('food_meals', 'Meals', 'food', 'food_meals'),
    ('drinks_hot', 'Hot Drinks', 'drinks', 'drinks_hot'),
    ('drinks_cold', 'Cold Drinks', 'drinks', 'drinks_cold'),
    ('drinks_dairy', 'Milk & Yogurt', 'drinks', 'drinks_dairy'),
  ];

  static const subcategoryDisplayOrder = <String>[
    'food_fruits',
    'food_vegetables',
    'food_dessert',
    'food_meals',
    'drinks_hot',
    'drinks_cold',
    'drinks_dairy',
  ];

  static const parentCategoriesWithSubcategories = {'food', 'drinks'};

  static bool hasSubcategories(String key) =>
      parentCategoriesWithSubcategories.contains(key);

  static int subcategoryOrderIndex(String key) {
    final index = subcategoryDisplayOrder.indexOf(key);
    return index >= 0 ? index : subcategoryDisplayOrder.length;
  }

  static int categoryOrderIndex(String key) {
    final index = categoryDisplayOrder.indexOf(key);
    return index >= 0 ? index : categoryDisplayOrder.length;
  }

  /// Legacy keys dropped from defaults; removed on seed so empty duplicates disappear.
  static const obsoleteCategoryKeys = ['foods'];

  /// When a legacy key is removed, reassign its phrases to the replacement key.
  static const obsoleteCategoryKeyMigrations = <String, String>{
    'foods': 'food',
  };

  /// (label, category key, path under assets/images/)
  static const defaultPhrases =
      <(String text, String categoryKey, String imageFile)>[
    // Activities
    ('I am drawing an animal', 'activities', 'Activities/I am drawing an animal.png'),
    ('I want to color', 'activities', 'Activities/I want to color.png'),
    ('I want to dance', 'activities', 'Activities/I want to dance.png'),
    ('I want to draw', 'activities', 'Activities/I want to draw.png'),
    ('I want to go outside', 'activities', 'Activities/I want to go outside.png'),
    ('I want to help', 'activities', 'Activities/I want to help.png'),
    ('I want to listen to music', 'activities', 'Activities/I want to listen to music.png'),
    ('I want to play', 'activities', 'Activities/I want to play.png'),
    ('I want to sing', 'activities', 'Activities/I want to sing.png'),
    ('I want to watch', 'activities', 'Activities/I want to watch.png'),
    // Animals
    ('Bee', 'animals', 'Animals/Bee.jpg'),
    ('Bird', 'animals', 'Animals/Bird.jpg'),
    ('Butterfly', 'animals', 'Animals/Butterfly.jpg'),
    ('Capybara', 'animals', 'Animals/Capybara.jpg'),
    ('Cat', 'animals', 'Animals/Cat.webp'),
    ('Chicken', 'animals', 'Animals/Chicken.jpg'),
    ('Cow', 'animals', 'Animals/Cow.jpg'),
    ('Dog', 'animals', 'Animals/Dog.jpg'),
    ('Duck', 'animals', 'Animals/Duck.jpg'),
    ('Elephant', 'animals', 'Animals/Elephant.webp'),
    ('Fish', 'animals', 'Animals/Fish.jpeg'),
    ('Frog', 'animals', 'Animals/Frog.jpg'),
    ('Giraffe', 'animals', 'Animals/Giraffe.jpg'),
    ('Goat', 'animals', 'Animals/Goat.jpg'),
    ('Horse', 'animals', 'Animals/Horse.jpg'),
    ('Lion', 'animals', 'Animals/Lion.jpg'),
    ('Monkey', 'animals', 'Animals/Monkey.jpg'),
    ('Mouse', 'animals', 'Animals/Mouse.jpg'),
    ('Pig', 'animals', 'Animals/Pig.jpg'),
    ('Rabbit', 'animals', 'Animals/Rabbit.jpeg'),
    ('Tiger', 'animals', 'Animals/Tiger.jpg'),
    // Colors
    ('Black', 'colors', 'Colors/Black.jpg'),
    ('Brown', 'colors', 'Colors/Brown.png'),
    ('Dark Blue', 'colors', 'Colors/Dark Blue.png'),
    ('Gray', 'colors', 'Colors/Gray.png'),
    ('Green', 'colors', 'Colors/Green.png'),
    ('Light Blue', 'colors', 'Colors/Light Blue.png'),
    ('Orange', 'colors', 'Colors/Orange.jpg'),
    ('Pink', 'colors', 'Colors/Pink.jpg'),
    ('Red', 'colors', 'Colors/Red.jpg'),
    ('Violet', 'colors', 'Colors/Violet.png'),
    ('White', 'colors', 'Colors/White.jpg'),
    ('Yellow', 'colors', 'Colors/Yellow.png'),
    // Drinks
    ('Coffee', 'drinks_hot', 'Drinks/Coffee.jpg'),
    ('Coke', 'drinks_cold', 'Drinks/Coke.jpg'),
    ('Cold Water', 'drinks_cold', 'Drinks/Cold Water.webp'),
    ('Delight', 'drinks_cold', 'Drinks/Delight.jpg'),
    ('Dutch Mill', 'drinks_dairy', 'Drinks/Dutch Mill.jpg'),
    ('Hot Water', 'drinks_hot', 'Drinks/Hot Water.jpg'),
    ('Milk', 'drinks_dairy', 'Drinks/Milk.jpg'),
    ('Milo', 'drinks_hot', 'Drinks/Milo.jpg'),
    ('Royal', 'drinks_cold', 'Drinks/Royal.jpg'),
    ('Sprite', 'drinks_cold', 'Drinks/Sprite.jpg'),
    ('Warm Water', 'drinks_hot', 'Drinks/Warm Water.jpg'),
    ('Yakult', 'drinks_dairy', 'Drinks/Yakult.jpg'),
    // Family
    ('Baby', 'family', 'Family/Baby.jpg'),
    ('Brother', 'family', 'Family/Brother.jpg'),
    ('Family', 'family', 'Family/Family.jpg'),
    ('Father', 'family', 'Family/Father.webp'),
    ('Grandma', 'family', 'Family/Grandma.jpg'),
    ('Grandpa', 'family', 'Family/Grandpa.jpg'),
    ('Mother', 'family', 'Family/Mother.jpg'),
    ('Sister', 'family', 'Family/Sister.jpg'),
    // Feelings
    ('Angry', 'feelings', 'Feelings/Angry.png'),
    ('I am Cold', 'feelings', 'Feelings/I am Cold.png'),
    ('I am Confuse', 'feelings', 'Feelings/I am Confuse.png'),
    ('I am Excited', 'feelings', 'Feelings/I am Excited.png'),
    ('I am Happy', 'feelings', 'Feelings/I am Happy.png'),
    ('I am Hot', 'feelings', 'Feelings/I am Hot.png'),
    ('I am Hungry', 'feelings', 'Feelings/I am Hungry.jpg'),
    ('I am Hurt', 'feelings', 'Feelings/I am Hurt.png'),
    ('I am Sad', 'feelings', 'Feelings/I am Sad.png'),
    ('I am Scared', 'feelings', 'Feelings/I am Scared.jpeg'),
    ('I am Tired', 'feelings', 'Feelings/I am Tired.png'),
    ('I Feel Lonely', 'feelings', 'Feelings/I Feel Lonely.png'),
    ('I Feel Sick', 'feelings', 'Feelings/I Feel Sick.jpeg'),
    ('Too Loud Noisy', 'feelings', 'Feelings/Too Loud Noisy.png'),
    // Foods
    ('Apple', 'food_fruits', 'Foods/Apple.jpg'),
    ('Banana', 'food_fruits', 'Foods/Banana.jpg'),
    ('Bread', 'food_meals', 'Foods/Bread.jpg'),
    ('Broccoli', 'food_vegetables', 'Foods/Broccoli.jpg'),
    ('Cake', 'food_dessert', 'Foods/Cake.jpg'),
    ('Carrots', 'food_vegetables', 'Foods/Carrots.jpg'),
    ('Chicken Adobo', 'food_meals', 'Foods/Chicken Adobo.jpg'),
    ('Chocolate', 'food_dessert', 'Foods/Chocolate.jpg'),
    ('Donuts', 'food_dessert', 'Foods/Donuts.jpg'),
    ('Egg', 'food_meals', 'Foods/Egg.jpg'),
    ('Eggplant', 'food_vegetables', 'Foods/Eggplant.jpg'),
    ('Fish Sinigang', 'food_meals', 'Foods/Fish Sinigang.jpg'),
    ('Fried Chicken', 'food_meals', 'Foods/Fried Chicken.jpg'),
    ('Fries', 'food_meals', 'Foods/Fries.jpg'),
    ('Grapes', 'food_fruits', 'Foods/Grapes.jpg'),
    ('Hot Dog', 'food_meals', 'Foods/Hot Dog.jpg'),
    ('Ice Cream', 'food_dessert', 'Foods/Ice Cream.jpg'),
    ('Mango', 'food_fruits', 'Foods/Mango.jpg'),
    ('Orange', 'food_fruits', 'Foods/Orange.jpg'),
    ('Pineaplle', 'food_fruits', 'Foods/Pineaplle.jpg'),
    ('Pizza', 'food_meals', 'Foods/Pizza.jpg'),
    ('Pork Adobo', 'food_meals', 'Foods/Pork Adobo.jpg'),
    ('Pork Sinigang', 'food_meals', 'Foods/Pork Sinigang.jpg'),
    ('Potato', 'food_vegetables', 'Foods/Potato.jpg'),
    ('Rice', 'food_meals', 'Foods/Rice.jpg'),
    ('Sandwich', 'food_meals', 'Foods/Sandwich.jpg'),
    ('Shrimp', 'food_meals', 'Foods/Shrimp.jpg'),
    ('Spaghetti', 'food_meals', 'Foods/Spaghetti.webp'),
    ('Squash', 'food_vegetables', 'Foods/Squash.jpg'),
    ('Watermelon', 'food_fruits', 'Foods/Watermelon.jpg'),
    // Greetings
    ('Excuse me', 'greetings', 'Greetings/Excuse me.png'),
    ('Good Morning', 'greetings', 'Greetings/Good Morning.png'),
    ('Good Night', 'greetings', 'Greetings/Good Night.png'),
    ('Goodbye', 'greetings', 'Greetings/Goodbye.jpeg'),
    ('Hello', 'greetings', 'Greetings/Hello.jpeg'),
    ('How are you', 'greetings', 'Greetings/How are you.png'),
    ('Nice to see you', 'greetings', 'Greetings/Nice to see you.png'),
    ('Sorry', 'greetings', 'Greetings/Sorry.jpeg'),
    ('Thank you', 'greetings', 'Greetings/Thank you.png'),
    ('Your welcome', 'greetings', 'Greetings/Your welcome.png'),
    // Health & Safety
    ('Call My Family', 'health_safety', 'Health & Safety/Call My Family.png'),
    ('Don\'t Touch Me', 'health_safety', 'Health & Safety/Don\'t Touch Me.jpg'),
    ('Emergency', 'health_safety', 'Health & Safety/Emergency.jpg'),
    ('Help Me', 'health_safety', 'Health & Safety/Help Me.jpg'),
    ('I Am Lost', 'health_safety', 'Health & Safety/I Am Lost.png'),
    ('I need a Doctor', 'health_safety', 'Health & Safety/I need a Doctor.png'),
    ('My Ear Hurts', 'health_safety', 'Health & Safety/My Ear Hurts.jpg'),
    ('My Eye Hurts', 'health_safety', 'Health & Safety/My Eye Hurts.jpeg'),
    ('My Hand Hurts', 'health_safety', 'Health & Safety/My Hand Hurts.png'),
    ('My Head Hurts', 'health_safety', 'Health & Safety/My Head Hurts.jpg'),
    ('My Leg Hurts', 'health_safety', 'Health & Safety/My Leg Hurts.jpg'),
    ('My Tooth Hurts', 'health_safety', 'Health & Safety/My Tooth Hurts.jpeg'),
    // Hobbies
    ('I like building things', 'hobbies', 'Hobbies/I like building things.png'),
    ('I like collecting things', 'hobbies', 'Hobbies/I like collecting things.png'),
    ('I like gardening', 'hobbies', 'Hobbies/I like gardening.png'),
    ('I like painting', 'hobbies', 'Hobbies/I like painting.png'),
    ('I like playing games', 'hobbies', 'Hobbies/I like playing games.png'),
    ('I like playing puzzles', 'hobbies', 'Hobbies/I like playing puzzles.png'),
    ('I like playing sports', 'hobbies', 'Hobbies/I like playing sports.png'),
    ('I like reading', 'hobbies', 'Hobbies/I like reading.png'),
    ('I like taking pictures', 'hobbies', 'Hobbies/I like taking pictures.png'),
    ('I like writing stories', 'hobbies', 'Hobbies/I like writing stories.png'),
    // Needs
    ('I am hungry', 'needs', 'Needs/I am hungry.png'),
    ('I am thirsty', 'needs', 'Needs/I am thirsty.png'),
    ('I need a snack', 'needs', 'Needs/I need a snack.png'),
    ('I need assistance', 'needs', 'Needs/I need assistance.png'),
    ('I need help', 'needs', 'Needs/I need help.png'),
    ('I need medicine', 'needs', 'Needs/I need medicine.png'),
    ('I need my device', 'needs', 'Needs/I need my device.png'),
    ('I need rest', 'needs', 'Needs/I need rest.png'),
    ('I need to go to the restroom', 'needs', 'Needs/I need to go to the restroom.png'),
    ('I need to wash my hands', 'needs', 'Needs/I need to wash my hands.png'),
    // Places
    ('Bakery', 'places', 'Places/Bakery.jpg'),
    ('Beach', 'places', 'Places/Beach.jpg'),
    ('Bedroom', 'places', 'Places/Bedroom.jpg'),
    ('Church', 'places', 'Places/Church.png'),
    ('Comfort room', 'places', 'Places/Comfort room.jpg'),
    ('Dining room', 'places', 'Places/Dining room.jpg'),
    ('Grocery Store', 'places', 'Places/Grocery Store.jpg'),
    ('Hospital', 'places', 'Places/Hospital.jpg'),
    ('Kitchen', 'places', 'Places/Kitchen.jpg'),
    ('Living room', 'places', 'Places/Living room.jpg'),
    ('Playground', 'places', 'Places/Playground.jpg'),
    ('Resort', 'places', 'Places/Resort.jpg'),
    ('School', 'places', 'Places/School.jpg'),
    ('Store', 'places', 'Places/Store.jpg'),
    // Responses
    ('Again', 'responses', 'Responses/Again.jpg'),
    ('Excuse Me', 'responses', 'Responses/Excuse Me.jpg'),
    ('Go', 'responses', 'Responses/Go.jpg'),
    ('Help', 'responses', 'Responses/Help.jpg'),
    ('I Understand', 'responses', 'Responses/I Understand.jpg'),
    ('Maybe', 'responses', 'Responses/Maybe.jpg'),
    ('No', 'responses', 'Responses/No.png'),
    ('Not Okay', 'responses', 'Responses/Not Okay.jpg'),
    ('Okay', 'responses', 'Responses/Okay.jpg'),
    ('Please', 'responses', 'Responses/Please.png'),
    ('Sorry', 'responses', 'Responses/Sorry.png'),
    ('Stop', 'responses', 'Responses/Stop.jpg'),
    ('Thank You', 'responses', 'Responses/Thank You.jpg'),
    ('What ', 'responses', 'Responses/What .jpg'),
    ('Where', 'responses', 'Responses/Where.png'),
    ('Who ', 'responses', 'Responses/Who .png'),
    ('Why ', 'responses', 'Responses/Why .jpg'),
    ('Yes', 'responses', 'Responses/Yes.jpg'),
    ('You Are Welcome', 'responses', 'Responses/You Are Welcome.avif'),
    // School
    ('Can I have a break', 'school', 'School/Can I have a break.png'),
    ('Can you help me', 'school', 'School/Can you help me.png'),
    ('Can you please read it again', 'school', 'School/Can you please read it again.png'),
    ('Can you repeat that', 'school', 'School/Can you repeat that.png'),
    ('I finished my work', 'school', 'School/I finished my work.png'),
    ('I know the answer', 'school', 'School/I know the answer.png'),
    ('I need a pencil', 'school', 'School/I need a pencil.png'),
    ('I need to charge my device', 'school', 'School/I need to charge my device.png'),
    ('I want to read a book', 'school', 'School/I want to read a book.png'),
    ('May I go to the restroom', 'school', 'School/May I go to the restroom.png'),
    // Technology
    ('Camera', 'technology', 'Technology/Camera.jpg'),
    ('Cellphone', 'technology', 'Technology/Cellphone.jpg'),
    ('Computer', 'technology', 'Technology/Computer.jpg'),
    ('Earphones', 'technology', 'Technology/Earphones.jpg'),
    ('Headphones', 'technology', 'Technology/Headphones.jpg'),
    ('Laptop', 'technology', 'Technology/Laptop.jpg'),
    ('Microwave', 'technology', 'Technology/Microwave.jpg'),
    ('Powerbank', 'technology', 'Technology/Powerbank.jpg'),
    ('Refrigerator', 'technology', 'Technology/Refrigerator.jpg'),
    ('Roouter', 'technology', 'Technology/Roouter.jpg'),
    ('Smartwatch', 'technology', 'Technology/Smartwatch.jpg'),
    ('Tablet', 'technology', 'Technology/Tablet.jpg'),
    ('Telephone', 'technology', 'Technology/Telephone.jpg'),
    ('Television', 'technology', 'Technology/Television.jpg'),
    // Transportation
    ('Ambulance', 'transportation', 'Transportation/Ambulance.jpg'),
    ('Bicycle', 'transportation', 'Transportation/Bicycle.jpg'),
    ('Bus', 'transportation', 'Transportation/Bus.jpg'),
    ('Car', 'transportation', 'Transportation/Car.jpg'),
    ('Fire truck', 'transportation', 'Transportation/Fire truck.jpg'),
    ('Jeepney', 'transportation', 'Transportation/Jeepney.jpg'),
    ('Motorcycle', 'transportation', 'Transportation/Motorcycle.jpg'),
    ('Police Car', 'transportation', 'Transportation/Police Car.jpg'),
    ('Taxi', 'transportation', 'Transportation/Taxi.jpg'),
    ('Train', 'transportation', 'Transportation/Train.jpg'),
    ('Tricycle', 'transportation', 'Transportation/Tricycle.jpg'),
    ('Truck', 'transportation', 'Transportation/Truck.jpg'),
    ('Van', 'transportation', 'Transportation/Van.jpg'),
  ];

  static String imageAsset(String imageFile) => 'assets/images/$imageFile';

  static String? imagePathForEntry((String, String, String) entry) =>
      imageAsset(entry.$3);
}