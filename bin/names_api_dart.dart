import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqlite3/sqlite3.dart';

void main() async {
  final database = await createConnectionToDB();
  createPeopleTable(database);

  // Take input name from the user and change for capital first letter:
  stdout.write('Enter a name: ');
  final inputName = stdin.readLineSync()!;
  final name =
      inputName[0].toUpperCase() + inputName.substring(1).toLowerCase();

  // Check if the person's information is already present in the database
  final selectQuery = database.prepare('SELECT * FROM people WHERE name = ?');
  final resultSet = selectQuery.select([name]);

  if (resultSet.isNotEmpty) {
    final row = resultSet.first;
    final name = row[0] as String;
    final gender = row[1] as String;
    final probability = row[2] as double;
    final savedPerson =
        Person(name: name, gender: gender, probability: probability);
    print('Person information retrieved from SQLite: $savedPerson');
  } else {
    // If person's information is not present in the database, get it from the API
    final person = await getPersonInformationFromAPI(name);

    // and add the missing person's information to the database
    addPersonToDatabase(database, person);
    print('Person information retrieved from API: $person');
  }

  // Get all the people's information from the database
  final peopleList = getAllPeopleFromDatabase(database);

  // Write the people's information to people.txt file
  writePeopleToFile(peopleList);

  // Dispose the database object
  database.dispose();
}

// Function to create a connection to the database
Future<Database> createConnectionToDB() async {
  final dbFile = File('people.db');
  final database = sqlite3.open('people.db');
  return database;
}

// Function to get person's information from the API
Future<Person> getPersonInformationFromAPI(String name) async {
  final url = Uri.parse('https://api.genderize.io/?name=$name');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final jsonResponse = json.decode(response.body);
    final person = Person.fromJson(jsonResponse);
    return person;
  } else {
    throw Exception('Failed to get person\'s information from API.');
  }
}

// Function to create people table in the database
void createPeopleTable(Database database) {
  database.execute('''
    CREATE TABLE IF NOT EXISTS people (
      name TEXT,
      gender TEXT,
      probability REAL
    )
  ''');
}

// Function to add person's information to the database
void addPersonToDatabase(Database database, Person person) {
  createPeopleTable(database);
  database.execute('INSERT INTO people VALUES (?, ?, ?)',
      [person.name, person.gender, person.probability]);
}

// Function to get all the people's information from the database
List<Person> getAllPeopleFromDatabase(Database database) {
  final peopleList = <Person>[];
  final selectAllQuery = database.prepare('SELECT * FROM people');
  final selectAllResultSet = selectAllQuery.select([]);

  for (final row in selectAllResultSet) {
    final name = row[0] as String;
    final gender = row[1] as String;
    final probability = row[2] as double;
    peopleList
        .add(Person(name: name, gender: gender, probability: probability));
  }

  return peopleList;
}

// Function to write people's information to people.txt file
void writePeopleToFile(List<Person> peopleList) {
  final file = File('people.txt');
  final sink = file.openWrite(mode: FileMode.writeOnly);
  for (final person in peopleList) {
    sink.write('${person.name}, ${person.gender}, ${person.probability}\n');
  }
  sink.close();
}

class Person {
  final String name;
  final String gender;
  final double probability;

  Person({required this.name, required this.gender, required this.probability});

  factory Person.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final gender = json['gender'] as String;
    final probability = json['probability'] as double;
    return Person(name: name, gender: gender, probability: probability);
  }

  @override
  String toString() {
    return 'Person(name: $name, gender: $gender, probability: $probability)';
  }
}
