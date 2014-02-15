# encoding: utf-8

require 'spec_helper'

describe 'Passthrough' do
  it 'renders pizza.de root page' do
    visit pizzade_root_path
    expect(page).to have_content('Pizza Lieferservice und Pizzaservice')
  end

  it 'renders shop page' do
    visit root_path + '/indian-curry-berlin-bruesseler-str-17?lgs=102261&ed=406536'
    expect(page).to have_content('Indian Curry | Brüsseler Str. 17 | 13353 Berlin')
    expect(page).to have_content('Missing Cookie')
  end

end
