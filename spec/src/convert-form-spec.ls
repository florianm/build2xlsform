# work around livescript syntax.
test = it

{ convert-form } = require('../lib/convert')

# because convert-form depends on accrued context from repeatedly calling
# convert-question and thus calls convert-question itself, this set of tests
# serve as an effective end-to-end test of the entire conversion pipeline
# from build-json to xls-json.
#
# the first set of tests focus on accurate schema generation of both sheets.
#
# the next set test basic row generation in all three sheets.
#
# the final set tests more-complex generation regimes involving groups/repeats.

# util.
describe 'schema generation:' ->
  describe 'main schema' ->
    test 'basic fields based on a question' ->
      result = convert-form(
        metadata:
          activeLanguages: [ \en ]
        controls: [
          { type: \inputText, name: \my_field, constraint: '. != "xyz"' }
        ]
      )

      expect(result[0].data[0]).toEqual([ \type, \name, \constraint ])

    test 'basic fields based on multiple questions' ->
      result = convert-form(
        metadata:
          activeLanguages: [ \en ]
        controls: [
          { type: \inputText, name: \my_field, constraint: '. != "xyz"' },
          { type: \inputText, name: \your_field, required: true }
        ]
      )

      expect(result[0].data[0]).toEqual([ \type, \name, \required, \constraint ])

    test 'ignores pruned fields' ->
      result = convert-form(
        metadata:
          activeLanguages: [ \en ]
        controls: [
          { type: \inputText, name: \my_field, label: {}, readOnly: false },
          { type: \inputText, name: \your_field, required: false }
        ]
      )

      expect(result[0].data[0]).toEqual([ \type, \name ])

    test 'ignores nonsense fields' ->
      result = convert-form(
        metadata:
          activeLanguages: [ \en ]
        controls: [
          { type: \inputText, name: \my_field, nonsense: \test },
          { type: \inputText, name: \your_field, other_nonsense: 3 }
        ]
      )

      expect(result[0].data[0]).toEqual([ \type, \name ])

    test 'generates appropriate language-keyed fields' ->
      result = convert-form(
        metadata:
          activeLanguages: [ \en, \sv, \hi ]
        controls: [
          { type: \inputText, label: { en: \hello }, hint: { en: \hi } },
          { type: \inputText, constraint_message: { hi: \challo } }
        ]
      )

      expect(result[0].data[0]).toEqual([ \type, \label::en, \label::sv, \label::hi, \hint::en, \hint::sv, \hint::hi, \constraint_message::en, \constraint_message::sv, \constraint_message::hi ])

  describe 'choice schema' ->
    test 'generation incl language-keyed fields' ->
      result = convert-form(
        metadata:
          activeLanguages: [ \en, \es ]
        controls: [ ]
      )

      expect(result[1].data[0]).toEqual([ 'list name', \name, \label::en, \label::es ])

describe 'row generation:' ->
  describe 'main sheet' ->
    test 'basic values end up in the correct spot' ->
      result = convert-form(
        metadata:
          activeLanguages: [ \en ]
        controls: [
          { type: \inputText, name: \my_field, constraint: '. != "xyz"' }
        ]
      )

      expect(result[0].data[1]).toEqual([ \text, \my_field, '(. != "xyz")' ])

    test 'absent values end up appropriately blank' ->
      result = convert-form(
        metadata:
          activeLanguages: [ \en ]
        controls: [
          { type: \inputText, name: \my_field },
          { type: \inputText, name: \other_field, required: true, readOnly: true }
        ]
      )

      expect(result[0].data[1]).toEqual([ \text, \my_field, undefined, undefined ])

    test 'appropriate number of rows in result' ->
      result = convert-form(
        metadata:
          activeLanguages: [ \en ]
        controls: [
          { type: \inputText, name: \my_field },
          { type: \inputText, name: \other_field },
          { type: \inputText, name: \yet_another_field }
        ]
      )

      expect(result[0].data.length).toEqual(4)

    test 'language-keyed fields correctly populated' ->
      result = convert-form(
        metadata:
          activeLanguages: [ \sv, \en ] # n.b. intentionally reversed from below.
        controls: [
          { type: \inputText, label: { en: \hello, sv: \hej }, hint: { en: \thanks, sv: \tack } }
        ]
      )

      expect(result[0].data[1]).toEqual([ \text, \hej, \hello, \tack, \thanks ])

    test 'partially missing language-keyed fields appropriately blank' ->
      result = convert-form(
        metadata:
          activeLanguages: [ \en, \sv ]
        controls: [
          { type: \inputText, label: { en: \hello }, hint: { sv: \tack } }
        ]
      )

      expect(result[0].data[1]).toEqual([ \text, \hello, undefined, undefined, \tack ])

    test 'entirely missing language-keyed fields appropriately blank' ->
      result = convert-form(
        metadata:
          activeLanguages: [ \sv, \en ]
        controls: [
          { type: \inputText, label: { en: \hello } },
          { type: \inputText, hint: { sv: \tack } }
        ]
      )

      expect(result[0].data[1]).toEqual([ \text, undefined, \hello, undefined, undefined ])

  describe 'choice sheet' ->
    test 'choice data correctly mapped' ->
      result = convert-form(
        metadata:
          activeLanguages: [ \en ]
        controls: [
          { type: \inputSelectOne, name: \testselect, options: [
            { text: { en: 'option a' }, val: \alpha }
          ] }
        ]
      )

      expect(result[1].data[1]).toEqual([ \choices_testselect, \alpha, 'option a' ])

    test 'expected number of choices outputted' ->
      result = convert-form(
        metadata:
          activeLanguages: [ \en ]
        controls: [
          { type: \inputSelectOne, name: \testselect, options: [
            { text: { en: 'option a' }, val: \alpha },
            { text: { en: 'option b' }, val: \bravo },
            { text: { en: 'option c' }, val: \charlie },
            { text: { en: 'option d' }, val: \delta }
          ] },
          { type: \inputSelectMany, name: \testselecttwo, options: [
            { text: { en: 'option e' }, val: \echo },
            { text: { en: 'option f' }, val: \foxtrot },
            { text: { en: 'option g' }, val: \golf },
            { text: { en: 'option h' }, val: \hotel }
          ] }
        ]
      )

      expect(result[1].data).toEqual([
        [ 'list name', \name, \label::en ],
        [ \choices_testselect, \alpha, 'option a' ],
        [ \choices_testselect, \bravo, 'option b' ],
        [ \choices_testselect, \charlie, 'option c' ],
        [ \choices_testselect, \delta, 'option d' ],
        [ \choices_testselecttwo, \echo, 'option e' ],
        [ \choices_testselecttwo, \foxtrot, 'option f' ],
        [ \choices_testselecttwo, \golf, 'option g' ],
        [ \choices_testselecttwo, \hotel, 'option h' ]
      ])

    test 'language-keyed field appropriately filled' ->
      result = convert-form(
        metadata:
          activeLanguages: [ \en, \es ]
        controls: [
          { type: \inputSelectOne, name: \testselect, options: [
            { text: { en: 'option a' }, val: \alpha },
            { text: { es: 'opción b' }, val: \bravo },
            { text: { en: 'option c', es: 'opción c' }, val: \charlie },
            { val: \delta }
          ] }
        ]
      )

      expect(result[1].data).toEqual([
        [ 'list name', \name, \label::en, \label::es ],
        [ \choices_testselect, \alpha, 'option a', undefined ],
        [ \choices_testselect, \bravo, undefined, 'opción b' ],
        [ \choices_testselect, \charlie, 'option c', 'opción c' ],
        [ \choices_testselect, \delta, undefined, undefined ]
      ])
