#!/usr/bin/env python
# coding: utf-8

"""
This script takes different data sets as input.
It cleans different data sets by removing extra rows from the top of the dataset.
Cleaned data is stored by creating a folder named "Clean_data". This script assumes that 'get-data.py' is run before.

Usage: claim_description.py --input_merged_path=<input_merged_path> --color_path=<color_path> --output_path=<output_path> 

Options:
--input_merged_path=<input_merged_path> A file path for merged data.
--color_path=<color> A file path for the list of colors.
--output_path=<output_path> A file path to store the verb colour and noun colour dataframes.

Example: 
python src/claim_analysis/claim_description.py \
--input_merged_path "results/claim_analysis/data/merged_collision.xlsx" \
--color_path "src/claim_analysis/data.json" \
--output_path "results/claim_analysis/report" 

"""

from docopt import docopt
import pandas as pd
import nltk
import spacy
from nltk import word_tokenize
from nltk.corpus import wordnet
import time
from collections import Counter
import numpy as np
import os

opt = docopt(__doc__)


def main(input_merged_path, color_path, output_path):
    """This function takes the claim data nd parses the claim description to create two different dataframes where nouns and verbs are mapped with different colours to store the results in the local system. These files are further used to create R shiny dashboard for the 		interactive visualisation

	Parameters
	-----------
	input_merged_path 
		A file path for merged data.
	color_path 
		A file path for the list of colors.
	output_path
		 A file path to store the verb colour dataframe.

	Returns
	----------
	None

	"""


    mid_df = pd.read_excel(input_merged_path)
    mid_df = mid_df.dropna(subset=['claim_desc', 'lat', 'long'])
    # loading model of spacy
    nlp = spacy.load("en_core_web_sm")
    # loading all the stopwords
    all_stopwords = nlp.Defaults.stop_words
    list_of_list = list()

    # for sentence in test['Claim_Desc']:
    for row in range(len(mid_df)):
        sentence = mid_df.iloc[row, 6]  # claim_dec
        occurrence_id = mid_df.iloc[row, 0]  # getting id for merging later
        loss_date_x = mid_df.iloc[row, 7]
        bus_category = mid_df.iloc[row, 19]
        bus_no_x = mid_df.iloc[row, 16]
        asset_manufacturer = mid_df.iloc[row, 42]
        lat = mid_df.iloc[row, 47]
        long = mid_df.iloc[row, 48]

        # declaring list of differrent pos tags

        intermediate_list = list()
        pos_list = list()
        noun_list = list()
        description_list = list()
        preposition_list = list()
        verb_list = list()
        adjective_list = list()
        # Removing the digits from the claim descriptions
        sentence = sentence.strip().lower()
        sentence = ''.join([i for i in sentence if not i.isdigit()])
        sentence = sentence.replace('- NO DMG', ' ')
        sentence = sentence.replace('-', ' ')

        text = nltk.word_tokenize(sentence)

        # Removing stopwords

        text_without_sw = [word for word in text if (
            not word in all_stopwords or not word.isdigit())]
        result = ' '.join(text_without_sw)
        spacy_ready_text = nlp(result)

        # POS tagging
        for token in spacy_ready_text:
            pos_list.append(token.pos_)
            if (token.pos_ == 'NOUN' or token.pos_ == 'PROPN') and len(token) > 2:
                noun_list.append(str(token.lemma_))
                # print(token.lemma_)
            elif token.pos_ == 'VERB' and len(token) > 2:
                # print(token.lemma_)
                verb_list.append(str(token.lemma_))
            elif token.pos_ == 'PROPN' and len(token) > 2:
                # print(token.lemma_)
                preposition_list.append(str(token.lemma_))

        tag = 'unknown'
        chosen_verb_list = list()
        if verb_list == [] and preposition_list != []:
            for w in preposition_list:
                syns = wordnet.synsets(w)
                if syns:
                    if syns[0].lexname().split('.')[0] == 'verb':
                        chosen_verb_list.append(w)
                    else:
                        continue
        if chosen_verb_list == []:
            chosen_verb_list = preposition_list

        elif preposition_list == [] and verb_list != []:
            for w in verb_list:
                syns = wordnet.synsets(w)
                if syns:
                    if syns[0].lexname().split('.')[0] == 'verb':
                        chosen_verb_list.append(w)
                    else:
                        continue
        if chosen_verb_list == []:
            chosen_verb_list = verb_list

        elif verb_list == [] and preposition_list == []:
            for w in noun_list:
                syns = wordnet.synsets(w)
                if syns:
                    if syns[0].lexname().split('.')[0] == 'verb' or syns[0].lexname().split('.')[0] == 'adj':
                        chosen_verb_list.append(w)
                    elif w == 'HIT':
                        chosen_verb_list.append(w)
                    else:
                        continue

        else:
            for w in verb_list:
                syns = wordnet.synsets(w)
                if syns:
                    if syns[0].lexname().split('.')[0] == 'verb':
                        chosen_verb_list.append(w)
                    else:
                        continue

        if chosen_verb_list == [] and verb_list != []:
            chosen_verb_list = verb_list

        elif chosen_verb_list == [] and preposition_list != []:
            chosen_verb_list = preposition_list

        impact_list = []
        if noun_list:
            last_noun = noun_list[-1]
            if len(last_noun) > 2:
                syns = wordnet.synsets(last_noun)
                if syns:
                    if syns[0].lexname().split('.')[0] == 'noun':
                        impact_list.append(last_noun)
                    else:
                        continue

        intermediate_list.extend([sentence, pos_list, preposition_list, verb_list, chosen_verb_list, pos_list,
                                    noun_list, impact_list, occurrence_id, loss_date_x, bus_category, bus_no_x, asset_manufacturer, lat, long])
        list_of_list.append(intermediate_list)

        
    pos_df = pd.DataFrame(list_of_list, columns=['Description', 'POS', 'preposition', 'verb', 'chosen_verb', 'pos', 'noun', 'impact', 'occurrence_id',\
                                                 'loss_date_x', 'bus_category', 'bus_no_x', 'asset_manufacturer', 'latt', 'long'])

    pos_df['impact'] = pos_df['impact'].apply(','.join).str.lower()
    pos_df['chosen_verb'] = pos_df['chosen_verb'].apply(','.join).str.lower()

    pos_df['impact'] = pos_df['impact'].replace(
        ['rr', 'rf', 'rl', 'lf', 'rd', 'rs', 's', 'l', 'ls'], 'side of the vehicle', regex=False)

    pos_df['impact'] = pos_df['impact'].replace(['dmgd', 'dmged', 'damae', 'damage',
                                                 'damaging', 'damdage', 'damge', 'dmge'], 'damaged', regex=False)

    pos_df['chosen_verb'] = pos_df['chosen_verb'].replace(['dmgd', 'dmged', 'damae', 'damage',
                                                           'damaging', 'damdage', 'damge', 'dmge'], 'damaged', regex=False)
    pos_df['chosen_verb'] = pos_df['chosen_verb'].replace(
        ['bone', 'boned'], 'T-bone', regex=False)

    pos_df['chosen_verb'] = pos_df['chosen_verb'].replace(['colledid', 'collide',
                                                           'colliede', 'colly'], 'collide', regex=False)

    pos_df['chosen_verb'] = pos_df['chosen_verb'].replace(
        ['block', 'blockie'], 'block', regex=False)
    pos_df['chosen_verb'] = pos_df['chosen_verb'].replace(
        ['brake', 'braked'], 'brake', regex=False)
    pos_df['chosen_verb'] = pos_df['chosen_verb'].replace(
        ['cause', 'causge'], 'cause', regex=False)

    pos_df['chosen_verb'] = pos_df['chosen_verb'].replace(
        ['end', 'endde', 'ene'], 'end', regex=False)

    pos_df['chosen_verb'] = pos_df['chosen_verb'].replace(
        ['force', 'forcing'], 'force', regex=False)
    pos_df['chosen_verb'] = pos_df['chosen_verb'].replace(
        ['reaende', 'rear', 'rearedne', 'rearend', 'rearende', 'rearenede'], 'hit 	rearend', regex=False)
    pos_df['chosen_verb'] = pos_df['chosen_verb'].replace(
        ['scapre', 'scrap', 'scrape', 'rsscrape'], 'scrape', regex=False)
    pos_df['chosen_verb'] = pos_df['chosen_verb'].replace(
        ['incur', 'injure', 'injurie'], 'injure', regex=False)
    pos_df['chosen_verb'] = pos_df['chosen_verb'].replace(
        ['swerve', 'swerved'], 'swerve', regex=False)
    pos_df['chosen_verb'] = pos_df['chosen_verb'].replace(
        ['slidde', 'slide'], 'slide', regex=False)
    pos_df['chosen_verb'] = pos_df['chosen_verb'].replace(
        ['sqeeze', 'squeese', 'squeeze'], 'squeeze', regex=False)
    pos_df['impact'] = pos_df['impact'].replace(
        ['veh'], 'vehicle', regex=False)
    pos_df['chosen_verb'] = pos_df['chosen_verb'].replace(
        ['veh'], 'vehicle', regex=False)
    pos_df['impact'] = pos_df['impact'].replace(
        ['tp'], 'Third party', regex=False)
    lst = ["BUS", "BUS", "TROLLEY", "POLES", "CUT", "TROLLEY", "ROPE"]
    checker_verb = dict()
    for i in pos_df['chosen_verb']:
        if ',' in i:
            action_list = i.split(',')
            for word in action_list:

                if word.lower() not in checker_verb:
                    checker_verb[word.lower()] = 1
                else:
                    checker_verb[word.lower()] += 1
        else:
            if i.lower() not in checker_verb:
                checker_verb[i.lower()] = 1
            else:
                checker_verb[i.lower()] += 1

    checker = dict()
    for i in pos_df['impact']:
        if i.lower() not in checker:
            checker[i.lower()] = 1
        else:
            checker[i.lower()] += 1
    Impacted_object_df = pd.DataFrame(checker.items(), columns=[
                                      'Impacted Object', 'Count']).sort_values(by='Count', ascending=False)
    Verbs_df = pd.DataFrame(checker.items(), columns=[
                            'Verbs', 'Count']).sort_values(by='Count', ascending=False)
    less_frequent_impact_objects = Impacted_object_df['Impacted Object'][Impacted_object_df['Count'] < 5]
    less_frequent_verbs = Verbs_df['Verbs'][Verbs_df['Count'] < 5]
    effective_impact = pos_df[~pos_df['impact'].isin(
        less_frequent_impact_objects)]

    list_of_colour = pd.read_json(color_path)[['name']]
    effective_impact_len = len(effective_impact)
    effective_impact['claim_id'] = np.arange(1, effective_impact_len+1, 1)
    intermediate_df = (effective_impact[['claim_id', 'chosen_verb']].set_index(['claim_id'])
                       .apply(lambda x: x.str.split(',').explode()).reset_index()

                       )
    exploded_verb_df = pd.merge(
        intermediate_df, effective_impact, on='claim_id')

    effective_verb = exploded_verb_df[~exploded_verb_df['chosen_verb_x'].isin(
        less_frequent_verbs)]

    checker_verb = dict()
    for i in effective_verb['chosen_verb_x']:
        if i.lower() not in checker_verb:
            checker_verb[i.lower()] = 1
        else:
            checker_verb[i.lower()] += 1
    effective_verbs_df = pd.DataFrame(checker_verb.items(), columns=[
                                      'Verbs', 'Count']).sort_values(by='Count', ascending=False)

    less_occuring_verbs = effective_verbs_df['Verbs'][effective_verbs_df['Count'] < 3]

    updated_verb = effective_verb[~effective_verb['chosen_verb_x'].isin(
        less_occuring_verbs)]

    impact_list = list(np.unique(effective_impact['impact']))
    impact_colour = list()
    for i in effective_impact['impact']:
        impact_colour.append(list_of_colour.iloc[impact_list.index(i)]['name'])

    verb_list = list(np.unique(updated_verb['chosen_verb_x']))
    verb_colour = list()
    for i in updated_verb['chosen_verb_x']:
        verb_colour.append(list_of_colour.iloc[verb_list.index(i)]['name'])

    effective_impact['impact_colour'] = impact_colour
    updated_verb['verb_colour'] = verb_colour

    result_df = effective_impact
    result_verb_df = updated_verb

    # replacing colours in the dataframe with nouns
    result_df = result_df.replace('Silver', 'skyblue')
    result_df = result_df.replace('Aqua', 'Pink')
    result_df = result_df.replace('Fuchsia', 'Red')
    result_df = result_df.replace('Lime', 'peachpuff')
    result_df = result_df.replace('Olive', 'orange')
    result_df = result_df.replace('Teal', 'yellowgreen')
    result_df = result_df.replace('SpringGreen3', 'SpringGreen')
    result_df = result_df.replace('Cyan3', 'Cyan')
    result_df = result_df.replace('DodgerBlue3', 'DodgerBlue')
    result_df = result_df.replace('DodgerBlue1', 'darkmagenta')
    result_df = result_df.replace('DodgerBlue2', 'gold')
    result_df = result_df.replace('DeepSkyBlue1', 'firebrick')
    result_df = result_df.replace('DeepSkyBlue2', 'DeepSkyBlue')
    result_df = result_df.replace('DeepSkyBlue3', 'thistle')
    result_df = result_df.replace('DeepSkyBlue4', 'tan')
    result_df = result_df.replace('Green1', 'forestgreen')
    result_df = result_df.replace('Green3', 'Green')
    result_df = result_df.replace('Green4', 'plum')
    result_df = result_df.replace('Turquoise3', 'rosybrown')
    result_df = result_df.replace('Turquoise4', 'royalblue')
    result_df = result_df.replace('Turquoise2', 'darkorange')
    result_df = result_df.replace('SpringGreen2', 'darksalmon')
    result_df = result_df.replace('SpringGreen1', 'darkgoldenrod')
    result_df = result_df.replace('DeepPink4', 'darkkhaki')
    result_df = result_df.replace('Blue3', 'chocolate')
    result_df = result_df.replace('Blue1', 'darkorchid')
    result_df = result_df.replace('violetred', 'blue')
    result_df = result_df.replace('SlateBlue3', 'limegreen')
    result_df = result_df.replace('burgundy', 'rosybrown')
    result_df = result_df.replace('SkyBlue2', 'sienna')
    result_df = result_df.replace('MediumPurple3', 'seagreen')
    result_df = result_df.replace('DarkOliveGreen3', 'sandybrown')
    result_df = result_df.replace('White', 'magenta')
    # replacing colours in the verb dataframe
    result_verb_df = result_verb_df.replace('Silver', 'skyblue')
    result_verb_df = result_verb_df.replace('Aqua', 'Pink')
    result_verb_df = result_verb_df.replace('Fuchsia', 'Red')
    result_verb_df = result_verb_df.replace('Lime', 'peachpuff')
    result_verb_df = result_verb_df.replace('Olive', 'orange')
    result_verb_df = result_verb_df.replace('Teal', 'yellowgreen')
    result_verb_df = result_verb_df.replace('SpringGreen3', 'SpringGreen')
    result_verb_df = result_verb_df.replace('Cyan3', 'Cyan')
    result_verb_df = result_verb_df.replace('DodgerBlue3', 'DodgerBlue')
    result_verb_df = result_verb_df.replace('DodgerBlue1', 'darkmagenta')
    result_verb_df = result_verb_df.replace('DodgerBlue2', 'gold')
    result_verb_df = result_verb_df.replace('DeepSkyBlue1', 'firebrick')
    result_verb_df = result_verb_df.replace('DeepSkyBlue2', 'DeepSkyBlue')
    result_verb_df = result_verb_df.replace('DeepSkyBlue3', 'thistle')
    result_verb_df = result_verb_df.replace('DeepSkyBlue4', 'tan')
    result_verb_df = result_verb_df.replace('Green1', 'forestgreen')
    result_verb_df = result_verb_df.replace('Green3', 'Green')
    result_verb_df = result_verb_df.replace('Green4', 'plum')
    result_verb_df = result_verb_df.replace('Turquoise3', 'rosybrown')
    result_verb_df = result_verb_df.replace('Turquoise4', 'royalblue')
    result_verb_df = result_verb_df.replace('Turquoise2', 'darkorange')
    result_verb_df = result_verb_df.replace('SpringGreen2', 'darksalmon')
    result_verb_df = result_verb_df.replace('SpringGreen1', 'darkgoldenrod')
    result_verb_df = result_verb_df.replace('DeepPink4', 'darkkhaki')
    result_verb_df = result_verb_df.replace('Blue3', 'chocolate')
    result_verb_df = result_verb_df.replace('Blue1', 'darkorchid')
    result_verb_df = result_verb_df.replace('violetred', 'blue')
    result_verb_df = result_verb_df.replace('SlateBlue3', 'limegreen')
    result_verb_df = result_verb_df.replace('burgundy', 'rosybrown')
    result_verb_df = result_verb_df.replace('SkyBlue2', 'sienna')
    result_verb_df = result_verb_df.replace('MediumPurple3', 'seagreen')
    result_verb_df = result_verb_df.replace('DarkOliveGreen3', 'sandybrown')
    result_verb_df = result_verb_df.replace('White', 'magenta')

    if not os.path.exists(output_path):
        os.makedirs(output_path)
    # saving the data with colours for unique nouns
    result_df.to_excel(output_path + '/claim_colour_df.xlsx', index=False)
    # saving the data with colours for unique verbs
    result_verb_df.to_excel(output_path + '/verb_colour_df.xlsx', index=False)


if __name__ == "__main__":
    main(opt['--input_merged_path'], opt['--color_path'], opt['--output_path'])
