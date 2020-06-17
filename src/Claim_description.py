#!/usr/bin/env python
# coding: utf-8

import pandas as pd
import nltk
import spacy
from nltk import word_tokenize
from nltk.corpus import wordnet
import time
from collections import Counter
collision_data_preventable = pd.read_csv("data/Clean_data/Collision_preventable.csv")
claim_data =  pd.read_csv("data/TransLink Raw Data/claim_vehicle_employee_line.csv")

Collision_preventable = pd.read_excel('data/TransLink Raw Data/2020 Collisions- Preventable and Non Preventable UBC Set Without Claim Number.xlsx', skiprows= 3)


# ### Checking the count of different events based on broader categories of incidents

count_df.sort_values(by=['Count'], ascending=False)

# loading model of spacy
nlp = spacy.load("en_core_web_sm")

# loading all the stopwords
all_stopwords = nlp.Defaults.stop_words

# trail dataset for performing test

list_of_list = list()
for sentence in Collision_preventable['Claim Desc.']:
    
    # declaring list of differrent pos tags
    intermediate_list = list()
    pos_list = list()
    noun_list = list()
    description_list = list()
    preposition_list = list()
    verb_list = list()
    adjective_list = list()
    # Removing the digits from the claim descriptions
    sentence = sentence.strip()
    sentence = ''.join([i for i in sentence if not i.isdigit()])
    sentence = sentence.replace('- NO DMG',' ')
    sentence = sentence.replace('-',' ')
    
    text = nltk.word_tokenize(sentence)
    
    
    #Removing stopwords
    
    text_without_sw = [word for word in text if (not word  in all_stopwords or  not word.isdigit())]
    result = ' '.join(text_without_sw)
    spacy_ready_text = nlp(result)
    
    # POS tagging
    for token in spacy_ready_text:
        pos_list.append(token.pos_)
        if token.pos_ == 'NOUN' or token.pos_ == 'PROPN':
            noun_list.append(str(token))
        elif token.pos_ == 'VERB':
            verb_list.append(str(token))
        elif token.pos_ == 'PROPN':
            preposition_list.append(str(token))

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
        impact_list.append(noun_list[-1])


    
        

        
    intermediate_list.extend([sentence, pos_list,preposition_list,verb_list, chosen_verb_list,pos_list, noun_list, impact_list ])
    list_of_list.append(intermediate_list)    
pos_df = pd.DataFrame(list_of_list, columns=['Description','POS','preposition','verb', 'chosen_verb', 'pos','noun','impact'])

pos_df['impact'] = pos_df['impact'].apply(','.join).str.lower()

pos_df['chosen_verb'] = pos_df['chosen_verb'].apply(','.join).str.lower()

pos_df['impact'] = pos_df['impact'].replace(['rr','rf','rl','lf','rd','rs','s','l','ls'], 'Side of the vehicle', regex= False)
pos_df['impact'] = pos_df['impact'].replace(['dmgd','dmged',], 'Damaged', regex= False)
pos_df['impact'] = pos_df['impact'].replace(['veh'], 'Vehicle', regex= False)
pos_df['impact'] = pos_df['impact'].replace(['tp'], 'Third party', regex= False)
lst = ["BUS", "BUS", "TROLLEY", "POLES", "CUT", "TROLLEY", "ROPE"]
checker_verb = dict()
for i in pos_df['chosen_verb']:
    if ',' in i:
        action_list = i.split(',')
        for word in action_list:
            
            if word.lower() not in checker_verb:
                checker_verb[word.lower()]= 1
            else:
                checker_verb[word.lower()]+= 1
    else:
        if i.lower() not in checker_verb:
            checker_verb[i.lower()]= 1
        else:
            checker_verb[i.lower()]+= 1

checker = dict()
for i in pos_df['impact']:
        if i.lower() not in checker:
            checker[i.lower()]= 1
        else:
            checker[i.lower()]+= 1
result_df = pd.concat([collision_data_preventable, pos_df['chosen_verb'],pos_df['pos'],pos_df['noun'], pos_df['impact']],axis = 1)

result_df.to_excel("../data/TransLink Raw Data/_df.xlsx", index= False)

Impacted_object_df = pd.DataFrame(checker.items(), columns= ['Impacted Object','Count']).sort_values(by='Count', ascending=False)
Impacted_object_df.to_excel("../data/TransLink Raw Data/Impacted_object_count.xlsx", index=False)
Verbs_df = pd.DataFrame(checker.items(), columns= ['Verbs','Count']).sort_values(by='Count', ascending=False)
Verbs_df.to_excel("../data/TransLink Raw Data/Verb_count.xlsx", index= False)
