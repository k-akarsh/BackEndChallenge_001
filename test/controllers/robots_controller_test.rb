require 'test_helper'

class RobotsControllerTest < ActionDispatch::IntegrationTest
  non_existent_robot_name = 'non-existent robot'

  test 'should get index' do
    3.times { create(:robot_with_two_attributes) }
    get robots_url, as: :json

    assert_response :success
    assert_equal(3, response.parsed_body.count)

    assert_includes(response.parsed_body.first, 'name')
    assert_includes(response.parsed_body.first, 'last_update')
  end

  test 'should show robot if robot exists' do
    robot = create(:robot_with_four_attributes)
    attribute = robot.robot_attributes.last

    get robot_url(robot.name), as: :json

    assert_response :success

    assert_equal(4, response.parsed_body.count)
    assert_equal(attribute.value, response.parsed_body[attribute.key])

    assert_includes(response.parsed_body, 'weight')
    assert_includes(response.parsed_body, 'color')

    assert_equal(robot.attributes_hash, response.parsed_body)
  end

  test 'should show proper message if robot does not exist' do
    get robot_url(non_existent_robot_name), as: :json

    assert_response :not_found
    assert_equal('Robot not found', response.parsed_body['message'])
  end

  test 'should create robot with all attributes if does not exist' do
    params = { robot: { color: 'red', weight: '100kg', height: '10m' } }

    assert_difference('Robot.count') do
      put robot_url(non_existent_robot_name), params: params, as: :json
    end

    last_robot = Robot.last

    assert_equal(non_existent_robot_name, last_robot.name)
    assert_equal(3, last_robot.robot_attributes.count)

    first_attribute = last_robot.robot_attributes.first
    last_attribute = last_robot.robot_attributes.last

    assert_equal('color', first_attribute.key)
    assert_equal('red', first_attribute.value)
    assert_equal('height', last_attribute.key)
    assert_equal('10m', last_attribute.value)

    assert_equal(3, response.parsed_body.count)
    assert_includes(response.parsed_body, 'color')
    assert_includes(response.parsed_body, 'weight')
    refute_includes(response.parsed_body, 'age')
    assert_equal('red', response.parsed_body['color'])

    assert_response 200
  end

  test 'should add or update robot attributes if exists' do
    robot = create(:robot_with_two_attributes)
    weight_attribute_old = robot.robot_attributes.find_by(key: 'weight')

    params = { robot: { age: '20years', weight: '50kg' } }

    assert_no_difference('Robot.count') do
      put robot_url(robot.name), params: params, as: :json
    end

    assert_equal(3, robot.robot_attributes.count)

    weight_attribute_new = robot.robot_attributes.find_by(key: 'weight')

    assert_equal('50kg', weight_attribute_new.value)
    assert_not_equal(weight_attribute_new.value, weight_attribute_old.value)

    assert_equal(3, response.parsed_body.count)
    refute_includes(response.parsed_body, 'eye_color')
    assert_includes(response.parsed_body, 'weight')
    assert_equal('20years', response.parsed_body['age'])
    assert_equal('50kg', response.parsed_body['weight'])

    assert_response 200
  end

  test 'history should give proper message if robot does not exist' do
    get robot_history_url(non_existent_robot_name), as: :json

    assert_response :not_found
    assert_equal(response.parsed_body['message'], 'Robot not found')
  end

  test 'history should return robot history if robot exists' do
    robot = create(:robot_with_four_attributes)

    travel 1.hour
    params_one = { robot: { age: '20years', weight: '50kg' } }
    put robot_url(robot.name), params: params_one, as: :json

    travel 1.day
    params_two = { robot: { weight: '10kg' } }
    put robot_url(robot.name), params: params_two, as: :json

    travel 1.hour
    params_three = { robot: { language: 'German', material: 'Iron' } }
    put robot_url(robot.name), params: params_three, as: :json

    get robot_history_url(robot.name), as: :json

    assert_equal(4, response.parsed_body.count)

    robot_created_time = robot.created_at.to_formatted_s(:db)
    weight_attribute_updated_time = robot.robot_attributes.find_by(key: 'weight').updated_at.to_formatted_s(:db)
    language_attribute_updated_time = robot.robot_attributes.find_by(key: 'language').updated_at.to_formatted_s(:db)

    assert_includes(response.parsed_body, robot_created_time)
    assert_includes(response.parsed_body, weight_attribute_updated_time)

    assert_equal('create', response.parsed_body[robot_created_time]['type'])
    assert_equal('update', response.parsed_body[weight_attribute_updated_time]['type'])
    assert_equal({ '50kg' => '10kg' }, response.parsed_body[weight_attribute_updated_time]['changes']['weight'])
    assert_equal({ '' => 'German' }, response.parsed_body[language_attribute_updated_time]['changes']['language'])

    assert_response 200
  end
end
